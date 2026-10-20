//! 数据库路径和连接池属于同一实例，成功初始化后一起交给宿主。

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::OnceLock;

use legado_core::{LegadoError, LegadoResult};
use legado_db::Database;
use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;

#[derive(Clone)]
pub struct StorageContext {
    pool: Pool<SqliteConnectionManager>,
    /// 从已打开的主数据库读取；内存库没有文件路径。
    path: Option<PathBuf>,
    blocking_slots: Arc<tokio::sync::Semaphore>,
    temporary: Arc<TemporaryDirectory>,
}

#[derive(Default)]
struct TemporaryDirectory(OnceLock<PathBuf>);

impl TemporaryDirectory {
    fn path(&self) -> LegadoResult<&Path> {
        if self.0.get().is_none() {
            let stamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map_err(|e| LegadoError::Internal(e.to_string()))?
                .as_nanos();
            let root = std::env::temp_dir();
            let mut candidate = None;
            for sequence in 0..100 {
                let path = root.join(format!(
                    "legado-storage-{}-{stamp}-{sequence}",
                    std::process::id()
                ));
                match std::fs::create_dir(&path) {
                    Ok(()) => {
                        candidate = Some(path);
                        break;
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
                    Err(e) => {
                        return Err(LegadoError::Internal(format!("创建实例数据目录失败: {e}")));
                    }
                }
            }
            let path =
                candidate.ok_or_else(|| LegadoError::Internal("实例目录名持续冲突".into()))?;
            if let Err(unused) = self.0.set(path) {
                // 并发失败者只回收自己独占创建的空目录，不处理调用者路径。
                let _ = std::fs::remove_dir(unused);
            }
        }
        Ok(self.0.get().expect("已分配实例目录").as_path())
    }
}

impl Drop for TemporaryDirectory {
    fn drop(&mut self) {
        if let Some(path) = self.0.take() {
            // 仅删除本对象独占创建的目录；文件库和外部目录永远不走此分支。
            let _ = std::fs::remove_dir_all(path);
        }
    }
}

impl StorageContext {
    pub(crate) fn from_database(db: Database) -> Self {
        let path = db
            .connection()
            .path()
            .filter(|path| !path.is_empty())
            .map(PathBuf::from);
        let pool = db.pool().clone();
        // 单连接内存库也必须先归还连接，后续操作才能重新借用。
        drop(db);
        let blocking_slots = Arc::new(tokio::sync::Semaphore::new(pool.max_size() as usize));
        Self {
            pool,
            path,
            blocking_slots,
            temporary: Arc::new(TemporaryDirectory::default()),
        }
    }

    pub fn path(&self) -> Option<&Path> {
        self.path.as_deref()
    }

    /// 文件库沿用相邻数据目录，内存库使用随数据能力寿命释放的私有目录。
    pub fn data_directory(&self, name: &str) -> LegadoResult<PathBuf> {
        let mut components = Path::new(name).components();
        if !matches!(components.next(), Some(std::path::Component::Normal(_)))
            || components.next().is_some()
        {
            return Err(LegadoError::Internal("数据子目录必须是单个普通名称".into()));
        }
        let parent = self
            .path
            .as_deref()
            .and_then(Path::parent)
            .filter(|p| !p.as_os_str().is_empty());
        let parent = match parent {
            Some(parent) => parent,
            None => self.temporary.path()?,
        };
        Ok(parent.join(name))
    }

    /// 短借一条连接；调用方不得跨网络、JS 或异步等待持有它。
    pub fn database(&self) -> LegadoResult<Database> {
        Database::from_pool(&self.pool)
    }

    /// 在同一连接上完成一次数据库操作或事务，结束即归还连接。
    pub fn with_database<T>(
        &self,
        operation: impl FnOnce(&Database) -> LegadoResult<T>,
    ) -> LegadoResult<T> {
        let db = self.database()?;
        operation(&db)
    }

    /// 异步入口在受限阻塞任务内完成取连接和 SQL，不把池等待留在 Tokio worker。
    /// 返回值可包含业务自己的 Result，连接获取/任务异常由外层结果传播。
    pub async fn run<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&Database) -> T + Send + 'static,
    ) -> LegadoResult<T> {
        let permit = self
            .blocking_slots
            .clone()
            .acquire_owned()
            .await
            .map_err(|e| LegadoError::Database(format!("数据库任务入口已关闭: {e}")))?;
        let storage = self.clone();
        tokio::task::spawn_blocking(move || {
            let _permit = permit;
            let db = storage.database()?;
            Ok(operation(&db))
        })
        .await
        .map_err(|e| LegadoError::Database(format!("数据库任务异常: {e}")))?
    }
}
