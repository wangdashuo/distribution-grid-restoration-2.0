function cfg = config()
% ===== 系统基准 =====
    cfg.baseMVA   = 10;
    cfg.baseKV    = 12.66;
    cfg.Vmin      = 0.94;
    cfg.Vmax      = 1.06;
    cfg.Pmax      = 0.60;
    cfg.T         = 4;
    cfg.dt        = 1;
    cfg.nCrew     = 1;

% ===== 目标权重 =====
    cfg.lambda_AI     = 2.0;    % 从 0.5 → 2.0，让 AI 引导更强
    cfg.VOLL_default  = 50;
    cfg.VOLL_scale    = 50;

% ===== 故障生成 =====
    cfg.maxFaults = 5;
    cfg.minFaults = 3;
    cfg.nScenarios= 20;

    cfg.useFastLabel = false;
    cfg.seed = 42;
end