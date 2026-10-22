//! 主脚本调用作用域：共享库留在父层，声明与参数只属于本次调用。— Codex + Rust

use super::{QuickJsEngine, SourceCall};
use crate::source_engine::CallResult;
use legado_core::{LegadoError, LegadoResult};
use rquickjs::object::{Accessor, AsProperty, Filter, PropertyFlags};
use rquickjs::{
    Ctx, Function, Object, Value,
    function::{Args, This},
    qjs,
};

/// 属性名不必是变量名；只把合法标识符作为参数，其他属性仍经对象读取。
fn parameter_name(name: &str) -> bool {
    let mut chars = name.chars();
    matches!(chars.next(), Some(c) if c.is_ascii_alphabetic() || c == '_' || c == '$')
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '$')
        && !matches!(
            name,
            "__legadoCode"
                | "arguments"
                | "await"
                | "break"
                | "case"
                | "catch"
                | "class"
                | "const"
                | "continue"
                | "debugger"
                | "default"
                | "delete"
                | "do"
                | "else"
                | "enum"
                | "export"
                | "extends"
                | "false"
                | "finally"
                | "for"
                | "function"
                | "if"
                | "import"
                | "in"
                | "instanceof"
                | "let"
                | "new"
                | "null"
                | "return"
                | "super"
                | "switch"
                | "this"
                | "throw"
                | "true"
                | "try"
                | "typeof"
                | "var"
                | "void"
                | "while"
                | "with"
                | "yield"
        )
}

/// 显式共享状态不经过本次绑定的临时访问器，允许它与普通声明同名。
/// 视图只保留JS对象引用，可由QuickJS正常追踪回收，不捕获Rust资源所有者。
pub(super) const STATE_FACTORY: &str = r#"(function(parent){
    const originals=Object.create(null);
    const has=Function.call.bind(Object.prototype.hasOwnProperty);
    const view=Object.create(Object.getPrototypeOf(parent));
    for(const key of Reflect.ownKeys(parent)){
        Object.defineProperty(view,key,{
            configurable:true,
            get(){
                let value;
                if(has(originals,key)){
                    const descriptor=originals[key];
                    value=descriptor===null ? undefined : has(descriptor,'value')
                        ? descriptor.value : descriptor.get ? descriptor.get.call(this) : undefined;
                }else{ value=Reflect.get(parent,key,this); }
                return value;
            },
            set(value){Object.defineProperty(this,key,{value:value,writable:true,enumerable:true,configurable:true});}
        });
    }
    const state=Object.create(view);
    state.globalThis=state;
    state.global=state;
    return {state:state,originals:originals};
})"#;

/// 精确保留父层属性描述，不通过执行清理脚本恢复，取消时也能解除借用。
struct Descriptor<'js> {
    flags: PropertyFlags,
    value: Value<'js>,
    get: Value<'js>,
    set: Value<'js>,
}

impl<'js> Descriptor<'js> {
    fn read(ctx: &Ctx<'js>, descriptor: Object<'js>) -> rquickjs::Result<Self> {
        let mut flags = qjs::JS_PROP_HAS_CONFIGURABLE | qjs::JS_PROP_HAS_ENUMERABLE;
        if descriptor.get::<_, bool>("configurable")? {
            flags |= qjs::JS_PROP_CONFIGURABLE;
        }
        if descriptor.get::<_, bool>("enumerable")? {
            flags |= qjs::JS_PROP_ENUMERABLE;
        }
        let undefined = Value::new_undefined(ctx.clone());
        let (value, get, set) = if descriptor.contains_key("value")? {
            flags |= qjs::JS_PROP_HAS_VALUE | qjs::JS_PROP_HAS_WRITABLE;
            if descriptor.get::<_, bool>("writable")? {
                flags |= qjs::JS_PROP_WRITABLE;
            }
            (descriptor.get("value")?, undefined.clone(), undefined)
        } else {
            flags |= qjs::JS_PROP_HAS_GET | qjs::JS_PROP_HAS_SET;
            (undefined, descriptor.get("get")?, descriptor.get("set")?)
        };
        Ok(Self {
            flags: flags as _,
            value,
            get,
            set,
        })
    }
}

impl<'js> AsProperty<'js, ()> for Descriptor<'js> {
    fn config(
        self,
        _: &Ctx<'js>,
    ) -> rquickjs::Result<(PropertyFlags, Value<'js>, Value<'js>, Value<'js>)> {
        Ok((self.flags, self.value, self.get, self.set))
    }
}

/// 父层函数的默认this及宿主嵌套求值都能读到当前绑定，退出后还原父层。
struct BorrowedBindings<'js> {
    parent: Object<'js>,
    current: Object<'js>,
    descriptor: Function<'js>,
    view_originals: Object<'js>,
    originals: Vec<(String, Option<Descriptor<'js>>)>,
}

impl<'js> BorrowedBindings<'js> {
    fn expose(&mut self, ctx: &Ctx<'js>) -> rquickjs::Result<()> {
        let keys = self
            .current
            .own_keys::<String>(Filter::new().string())
            .collect::<rquickjs::Result<Vec<_>>>()?;
        for key in keys {
            let original: Option<Object> =
                self.descriptor.call((self.parent.clone(), key.clone()))?;
            // jsLib自己的不可配置声明留在库作用域，不把业务声明覆盖到库内。
            if original
                .as_ref()
                .is_some_and(|d| d.get::<_, bool>("configurable").ok() == Some(false))
            {
                continue;
            }
            let saved = original
                .clone()
                .map(|d| Descriptor::read(ctx, d))
                .transpose()?;
            self.originals.push((key.clone(), saved));
            self.view_originals.set(
                key.as_str(),
                original
                    .clone()
                    .map(Object::into_value)
                    .unwrap_or_else(|| Value::new_null(ctx.clone())),
            )?;
            let read = self.current.clone();
            let write = self.current.clone();
            let read_key = key.clone();
            let write_key = key.clone();
            self.parent.prop(
                key.as_str(),
                Accessor::from(move || read.get::<_, Value>(read_key.as_str()))
                    .set(move |value: Value<'js>| write.set(write_key.as_str(), value))
                    .configurable()
                    .enumerable(),
            )?;
        }
        Ok(())
    }

    fn restore(&mut self) -> rquickjs::Result<()> {
        let mut failure = None;
        while let Some((key, original)) = self.originals.pop() {
            let restored = match original {
                Some(descriptor) => self.parent.prop(key.as_str(), descriptor),
                None => self.parent.remove(key.as_str()),
            };
            for result in [restored, self.view_originals.remove(key.as_str())] {
                if let Err(error) = result {
                    failure.get_or_insert(error);
                }
            }
        }
        failure.map_or(Ok(()), Err)
    }
}

impl Drop for BorrowedBindings<'_> {
    fn drop(&mut self) {
        // 正常返回显式检查恢复结果；异常解栈时也不能把调用对象留在缓存父层。
        let _ = self.restore();
    }
}

pub(super) fn run<'js>(
    ctx: &Ctx<'js>,
    parent: Object<'js>,
    state: Object<'js>,
    view_originals: Object<'js>,
    call: &SourceCall<'_>,
) -> LegadoResult<CallResult> {
    let error = |error: rquickjs::Error| match error {
        rquickjs::Error::Exception => {
            LegadoError::JsEngine(QuickJsEngine::take_exception_message(ctx))
        }
        error => LegadoError::JsEngine(format!("主脚本调用失败: {error}")),
    };
    let current = Object::new(ctx.clone()).map_err(error)?;
    let object: Object = parent.get("Object").map_err(error)?;
    let descriptor: Function = object.get("getOwnPropertyDescriptor").map_err(error)?;
    current.set_prototype(Some(&state)).map_err(error)?;
    // 复用库的Java命名空间，书源方法只挂在本次调用对象上。
    let java = Object::new(ctx.clone()).map_err(error)?;
    java.set_prototype(Some(&parent.get("java").map_err(error)?))
        .map_err(error)?;
    current.set("java", java).map_err(error)?;
    current.set("globalThis", current.clone()).map_err(error)?;
    current.set("global", current.clone()).map_err(error)?;
    let mut bridge = BorrowedBindings {
        parent: parent.clone(),
        current: current.clone(),
        descriptor,
        view_originals,
        originals: Vec::new(),
    };
    let outcome = (|| -> LegadoResult<CallResult> {
        // 同一Context内建立函数词法环境，库的let/const继续沿外层可见。
        // with只位于声明环境外侧，mainJs的var不会写入共享同名属性。
        // 两次直接eval保留setup辅助函数，并按脚本语法检查mainJs（非法return仍报错）。
        let mut options = rquickjs::context::EvalOptions::default();
        options.strict = false;
        let factory: Function = ctx.eval_with_options(
            "(function(__legadoScope){with(__legadoScope){return function(){eval(arguments[0]);return function(){return eval(arguments[0]);};};}})",
            options,
        ).map_err(error)?;
        let setup: Function = factory.call((current.clone(),)).map_err(error)?;
        let evaluate: Function = setup
            .call((This(current.clone()), call.setup))
            .map_err(error)?;
        QuickJsEngine::inject_object_bindings(ctx, &current, call.args)?;
        // 上游显式globalThis/global属于来源共享状态，普通声明留在函数词法环境。
        current.set("globalThis", state.clone()).map_err(error)?;
        current.set("global", state.clone()).map_err(error)?;
        bridge.expose(ctx).map_err(error)?;
        let names = call
            .args
            .iter()
            .map(|(name, _)| *name)
            .collect::<Vec<_>>()
            .join(",");
        let expression = if call.optional {
            format!(
                "typeof {name}==='function'?{{exists:true,value:{name}({names})}}:{{exists:false}}",
                name = call.name
            )
        } else {
            format!("{{exists:true,value:{}({names})}}", call.name)
        };
        let script = format!("{}\n;({expression})", call.main_js);
        // 预置的source等作为函数参数，var同名重声明保留初值；eval内let/const
        // 仍可独立遮蔽。否则函数内var提升会让“先读source、再声明source”读到undefined。
        let parameters = current
            .own_keys::<String>(Filter::new().string())
            .collect::<rquickjs::Result<Vec<_>>>()
            .map_err(error)?
            .into_iter()
            .filter(|name| parameter_name(name))
            .collect::<Vec<_>>();
        let evaluator = format!(
            "(function(__legadoCode,{}){{return eval(__legadoCode);}})",
            parameters.join(",")
        );
        let execute: Function = evaluate
            .call((This(current.clone()), evaluator))
            .map_err(error)?;
        let mut args = Args::new(ctx.clone(), parameters.len() + 1);
        args.this(current.clone()).map_err(error)?;
        args.push_arg(script).map_err(error)?;
        for name in parameters {
            args.push_arg(current.get::<_, Value>(name.as_str()).map_err(error)?)
                .map_err(error)?;
        }
        let outcome: Object = execute.call_arg(args).map_err(error)?;
        if !outcome.get::<_, bool>("exists").map_err(error)? {
            return Ok(CallResult::not_found());
        }
        let result: Value = outcome.get("value").map_err(error)?;
        let value = QuickJsEngine::source_result(ctx, &result)?;
        crate::cancellation::check()?;
        Ok(CallResult::success(value))
    })();
    let restored = bridge.restore().map_err(error);
    outcome.and_then(|result| restored.map(|_| result))
}
