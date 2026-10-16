function fig9_critical_ens(results, sys, cfg, saveDir)
% FIG9_CRITICAL_ENS  分类别失电量对比
%   - 第1-4场景（MILP组）单独对比
%   - 第5场景（AI-fast）单独对比
%   避免 S5 的离群值污染视觉

    style_poster(); C = poster_colors();
    K = numel(results);
    names = {'S1','S2','S3','S4','S5'};
    succ = [results.success];

    %% ---- 收集分类别 ENS ----
    ENS_DC   = nan(K,1);
    ENS_Hos  = nan(K,1);
    ENS_Ind  = nan(K,1);
    ENS_Res  = nan(K,1);
    ENS_crit = nan(K,1);

    for k = 1:K
        if ~succ(k), continue; end
        ENS_DC(k)   = results(k).ENS_DC;
        ENS_Hos(k)  = results(k).ENS_Hos;
        ENS_Ind(k)  = results(k).ENS_Ind;
        ENS_Res(k)  = results(k).ENS_Res;
        ENS_crit(k) = results(k).ENS_crit;
    end

    %% ============ 图 ============
    fig = figure('Position',[50 50 1700 560]);

    % ---------- (a) S1-S4 关键负荷对比（核心图）----------
    subplot(1,3,1);
    K4 = min(4, K);
    b = bar(1:K4, [ENS_DC(1:K4), ENS_Hos(1:K4)], 'grouped', ...
            'EdgeColor','k','LineWidth',1.2);
    b(1).FaceColor = C.dc;
    b(2).FaceColor = C.hos;
    set(gca,'XTickLabel', names(1:K4),'FontSize',14);
    ylabel('关键负荷失电量 (MWh)','FontSize',14);
    title('(a) 关键负荷恢复对比（MILP 组）','FontSize',15);
    legend({'数据中心','医院'},'Location','northeast','FontSize',11);
    grid on;
    for k = 1:K4
        if succ(k)
            text(k-0.15, ENS_DC(k)*1.08+max(ENS_DC)*0.02, ...
                 sprintf('%.3f',ENS_DC(k)), ...
                 'HorizontalAlignment','center','FontSize',10, ...
                 'FontWeight','bold','Color',C.dc);
            text(k+0.15, ENS_Hos(k)*1.08+max(ENS_Hos)*0.02, ...
                 sprintf('%.3f',ENS_Hos(k)), ...
                 'HorizontalAlignment','center','FontSize',10, ...
                 'FontWeight','bold','Color',C.hos);
        end
    end
    ylim([0 max([ENS_DC(1:K4); ENS_Hos(1:K4)])*1.3 + 1e-6]);

    % ---------- (b) S1-S4 分类别失电构成 ----------
    subplot(1,3,2);
    M4 = [ENS_DC(1:K4), ENS_Hos(1:K4), ENS_Ind(1:K4), ENS_Res(1:K4)];
    bar(1:K4, M4, 'stacked','EdgeColor','k','LineWidth',1.2);
    set(gca,'XTickLabel', names(1:K4),'FontSize',14);
    ylabel('失电量 (MWh)','FontSize',14);
    title('(b) 失电量构成（MILP 组）','FontSize',15);
    legend({'数据中心','医院','大工业','普通负荷'}, ...
           'Location','northeast','FontSize',10);
    grid on;

    % ---------- (c) S1-S4 关键负荷下降幅度 ----------
    subplot(1,3,3);
    if succ(1) && ENS_crit(1) > 1e-6
        impCrit = (ENS_crit(1) - ENS_crit) / ENS_crit(1) * 100;
        impCrit(~isfinite(impCrit)) = 0;
        % 只画 S1-S4
        vals = impCrit(1:K4);
        b = bar(1:K4, vals, 'FaceColor',[0.20 0.70 0.35], 'EdgeColor','k', ...
                'LineWidth',1.2);
        set(gca,'XTickLabel', names(1:K4),'FontSize',14);
        ylabel('关键负荷失电量下降 (%)','FontSize',14);
        title('(c) 相对 S1 的关键负荷改进','FontSize',15);
        for k = 1:K4
            if vals(k) >= 0
                text(k, vals(k)+3, sprintf('+%.1f%%',vals(k)), ...
                     'HorizontalAlignment','center','FontSize',11, ...
                     'FontWeight','bold','Color',[0 0.5 0]);
            else
                text(k, vals(k)-5, sprintf('%.1f%%',vals(k)), ...
                     'HorizontalAlignment','center','FontSize',11, ...
                     'FontWeight','bold','Color','r');
            end
        end
        yline(0, 'k-', 'LineWidth', 1);
        ylim([min([vals, 0])*1.3 - 5, max([vals, 0])*1.3 + 5]);
    else
        bar(zeros(K4,1));
        text(K4/2, 0.5, 'S1 关键负荷 ENS = 0', ...
             'HorizontalAlignment','center','FontSize',12,'Color','r');
        ylim([-1 1]);
    end
    grid on;

    sgtitle('关键负荷恢复效果（S1-S4 为 MILP 组，S5 单列）', ...
            'FontSize',16,'FontWeight','bold');

    exportgraphics(fig, fullfile(saveDir,'fig9_critical_ens.png'), ...
                   'Resolution', 300);
    fprintf('    → 保存: fig9_critical_ens.png\n');

    %% ============ 图2：S5 单独展示 ============
    fig2 = figure('Position',[100 100 900 500]);
    if succ(5)
        M5 = [ENS_DC(5), ENS_Hos(5), ENS_Ind(5), ENS_Res(5)];
        b = bar(1, M5, 'stacked','EdgeColor','k','LineWidth',1.5);
        set(gca,'XTickLabel',{'S5: AI-only 快速决策'},'FontSize',13);
        ylabel('失电量 (MWh)','FontSize',14);
        title('S5 快速决策的失电构成（对比参考，量级不同）', ...
              'FontSize',14);
        legend({'数据中心','医院','大工业','普通负荷'}, ...
               'Location','northeast','FontSize',11);
        grid on;
    end
    exportgraphics(fig2, fullfile(saveDir,'fig9b_s5_standalone.png'), ...
                   'Resolution', 300);
    fprintf('    → 保存: fig9b_s5_standalone.png\n');

    %% ============ 命令行明细 ============
    fprintf('\n========= 分类别失电量 =========\n');
    fprintf('%-6s | %10s | %10s | %10s | %10s | %10s\n', ...
            '场景','DC(MWh)','医院(MWh)','工业(MWh)','居民(MWh)','关键合计');
    for k = 1:K
        if succ(k)
            fprintf('%-6s | %10.4f | %10.4f | %10.4f | %10.4f | %10.4f\n', ...
                    names{k}, ENS_DC(k), ENS_Hos(k), ...
                    ENS_Ind(k), ENS_Res(k), ENS_crit(k));
        else
            fprintf('%-6s | %10s | %10s | %10s | %10s | %10s\n', ...
                    names{k}, 'N/A','N/A','N/A','N/A','N/A');
        end
    end
end