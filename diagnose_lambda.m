function diagnose_lambda(sys, cfg)
% 扫描 lambda_AI，观察 ENS 随 λ 的变化
% 如果存在某个 λ，使得 ENS 最小，说明 AI 有信息
% 如果 λ=0 就是最优，说明 AI 完全无效或方向错误

    rng(cfg.seed);
    testFault = generate_fault_scenario(sys, cfg);

    % 训练一次模型（用现有流程）
    [X, Y] = generate_training_data(sys, cfg);
    model  = train_priority_model(X, Y);
    wAI    = predict_priority(model, testFault, sys, cfg);

    lambdas = [0, 0.05, 0.1, 0.2, 0.5, 1, 2, 4, 8];
    ENS_p   = zeros(size(lambdas));
    ENS_r   = zeros(size(lambdas));

    for i = 1:numel(lambdas)
        cfg2 = cfg; cfg2.lambda_AI = lambdas(i);

        r1 = solve_restoration(testFault, wAI, sys, cfg2, 'plain');
        r2 = solve_restoration(testFault, wAI, sys, cfg2, 'reliability');
        ENS_p(i) = r1.ENS;
        ENS_r(i) = r2.ENS;
        fprintf('  λ=%5.2f | plain ENS=%.4f | reliability ENS=%.4f\n', ...
                lambdas(i), ENS_p(i), ENS_r(i));
    end

    figure('Name','λ_AI 诊断');
    subplot(1,2,1);
    plot(lambdas, ENS_p, '-o','LineWidth',1.5); hold on;
    xline(8, 'r--', 'λ_{当前}=8'); xlabel('λ_{AI}'); ylabel('ENS (MWh)');
    title('纯失电模式：ENS vs λ_{AI}'); grid on;

    subplot(1,2,2);
    plot(lambdas, ENS_r, '-s','LineWidth',1.5); hold on;
    xline(8, 'r--', 'λ_{当前}=8'); xlabel('λ_{AI}'); ylabel('加权 ENS (MWh)');
    title('可靠性模式：ENS vs λ_{AI}'); grid on;
end