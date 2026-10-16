function fig7_runtime(results, sys, cfg, saveDir)
% FIG7_RUNTIME  求解时间 vs 精度（AI 加速效果，5 场景，NaN 安全）
%   左图：各场景求解时间柱状图（对数纵轴）
%   中图：各场景经济损失
%   右图：速度-精度 tradeoff 散点图

    style_poster(); C = poster_colors();
    K = numel(results);
    shortNames = {'S1','S2','S3','S4','S5'};
    cols = {C.S1, C.S2, C.S3, C.S4, C.S5};

    runtime = [results.runtime];
    lossUSD = [results.ENS_w];
    ens     = [results.ENS];
    succ    = [results.success];

    % ★ 失败场景：耗时仍有效（真的花了时间），但损失无效
    lossUSD(~succ) = NaN;
    ens(~succ)     = NaN;

    fig = figure('Position',[50 50 1800 560]);

    %% ============ (a) 求解时间 ============
    subplot(1,3,1);
    b = bar(runtime, 'FaceColor','flat','EdgeColor','k','LineWidth',1.2);
    for k = 1:K
        if k <= numel(cols)
            b.CData(k,:) = cols{k};
        end
    end
    set(gca, 'YScale', 'log');
    set(gca,'XTickLabel', shortNames,'FontSize',13);
    ylabel('求解时间 (秒, 对数)','FontSize',14);
    title('(a) 各策略求解时间','FontSize',15);
    for k = 1:K
        if runtime(k) >= 1
            txt = sprintf('%.2f s', runtime(k));
        elseif runtime(k) >= 1e-3
            txt = sprintf('%.1f ms', runtime(k)*1000);
        else
            txt = sprintf('%.1f µs', runtime(k)*1e6);
        end
        text(k, runtime(k)*1.3, txt, ...
             'HorizontalAlignment','center','FontSize',10,'FontWeight','bold');
    end
    grid on;

    % 标注 AI 加速比（只在 MILP 全部成功 + AI-fast 成功时）
    if all(succ(1:4)) && succ(5)
        mean_milp = mean(runtime(1:4));
        accel = mean_milp / max(runtime(5), 1e-6);
        text(3, mean_milp*30, sprintf('AI 加速 %.0f×', accel), ...
             'HorizontalAlignment','center','FontSize',12,'FontWeight','bold', ...
             'Color', C.S5, 'BackgroundColor',[1 1 0.8],'Margin',3);
    end

    %% ============ (b) 经济损失 ============
    subplot(1,3,2);
    b = bar(lossUSD/1000, 'FaceColor','flat','EdgeColor','k','LineWidth',1.2);
    for k = 1:K
        if succ(k) && k <= numel(cols)
            b.CData(k,:) = cols{k};
        else
            b.CData(k,:) = [0.6 0.6 0.6];
        end
    end
    set(gca,'XTickLabel', shortNames,'FontSize',13);
    ylabel('经济损失 (千美元)','FontSize',14);
    title('(b) 各策略经济损失','FontSize',15);
    yl = ylim();
    for k = 1:K
        if succ(k)
            text(k, lossUSD(k)/1000*1.03, sprintf('%.1f', lossUSD(k)/1000), ...
                 'HorizontalAlignment','center','FontSize',10,'FontWeight','bold');
        else
            text(k, yl(2)*0.5, 'N/A', 'HorizontalAlignment','center', ...
                 'FontSize',11,'Color','r','FontWeight','bold');
        end
    end
    grid on;

    %% ============ (c) 速度-精度 tradeoff ============
    subplot(1,3,3); hold on;
    validIdx = find(succ);
    for ii = 1:numel(validIdx)
        k = validIdx(ii);
        if k <= numel(cols)
            col = cols{k};
        else
            col = [0.5 0.5 0.5];
        end
        scatter(runtime(k), lossUSD(k)/1000, 220, col, 'filled', ...
                'MarkerEdgeColor','k','LineWidth',1.5);
        text(runtime(k)*1.35, lossUSD(k)/1000, shortNames{k}, ...
             'FontSize',12,'FontWeight','bold','Color',col);
    end
    set(gca, 'XScale', 'log');
    xlabel('求解时间 (秒, 对数)','FontSize',14);
    ylabel('经济损失 (千美元)','FontSize',14);
    title('(c) 速度-精度权衡','FontSize',15);
    grid on;

    % Pareto 前沿（只用有效点）
    if numel(validIdx) >= 2
        [rt_sorted, idx] = sort(runtime(validIdx));
        loss_sorted = lossUSD(validIdx);
        loss_sorted = loss_sorted(idx);
        plot(rt_sorted, loss_sorted/1000, 'k--', 'LineWidth', 1.2, ...
             'HandleVisibility','off');
    end

    % 突出 S5（若 S4 和 S5 都成功）
    if succ(4) && succ(5) && lossUSD(4) > 0
        text(runtime(5), lossUSD(5)/1000, ...
             sprintf('  ← %.1f ms\n    损失高 %.1f%%', ...
                     runtime(5)*1000, ...
                     (lossUSD(5)-lossUSD(4))/lossUSD(4)*100), ...
             'FontSize',11,'FontWeight','bold','Color',C.S5);
    end

    %% ============ 标题 ============
    if all(succ(1:4)) && succ(5)
        mean_milp = mean(runtime(1:4));
        accel = mean_milp / max(runtime(5), 1e-6);
        sgtitle(sprintf(['AI 求解加速效果（平均 MILP 耗时 %.1f s → ' ...
                         'AI-fast %.1f ms，加速 %.0f×）'], ...
                mean_milp, runtime(5)*1000, accel), ...
                'FontSize',16,'FontWeight','bold');
    else
        sgtitle('AI 求解加速效果（有场景失败，加速比未计算）', ...
                'FontSize',16,'FontWeight','bold');
    end

    exportgraphics(fig, fullfile(saveDir,'fig7_runtime.png'), 'Resolution', 300);
    fprintf('    → 保存: fig7_runtime.png\n');

    %% ============ 命令行明细 ============
    fprintf('\n========= AI 求解加速 =========\n');
    fprintf('%-32s | %12s | %12s | %8s\n','场景','用时(s)','损失(千$)','success');
    for k = 1:K
        if succ(k)
            fprintf('%-32s | %12.4f | %12.2f | %8s\n', ...
                    results(k).name, runtime(k), lossUSD(k)/1000, '✓');
        else
            fprintf('%-32s | %12.4f | %12s | %8s\n', ...
                    results(k).name, runtime(k), 'N/A', '✗');
        end
    end

    if all(succ(1:4)) && succ(5)
        mean_milp = mean(runtime(1:4));
        fprintf('\nMILP 平均耗时: %.2f 秒\n', mean_milp);
        fprintf('AI 快速决策:   %.4f 秒 (%.1f ms)\n', runtime(5), runtime(5)*1000);
        fprintf('加速比:        %.0f 倍\n', mean_milp / max(runtime(5),1e-6));
        if lossUSD(4) > 0
            fprintf('AI 精度差距:   损失高 %.2f%%\n', ...
                    (lossUSD(5)-lossUSD(4))/lossUSD(4)*100);
        end
    else
        fprintf('\n[跳过] 加速比计算（有场景失败）\n');
    end
end