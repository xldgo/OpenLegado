// 领域能力由应用装配提供，读取仓储不隐式初始化原生库。— Codex + UI
export '../../app/bootstrap/application_dependencies.dart'
    show
        searchServiceProvider,
        contentSearchServiceProvider,
        searchHistoryRepositoryProvider,
        searchAggregationServiceProvider;
