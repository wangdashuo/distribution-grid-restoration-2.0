function fig6_summary_table(results, sys, cfg, saveDir)
% FIG6_SUMMARY_TABLE  汇总表（含 success 列，NaN 安全）

    style_poster();
    K = numel(results);

    succ = [results.success];
    names = cell(K,1);
    ens   = nan(K,1);
    loss  = nan(K,1);
    salvage_MWh = nan(K,1);
    salvage_USD = nan(K,1);
    dcT   = nan(K,1);
    hosT  = nan(K,1);

    dcIdx  = find(strcmp(sys.nodeType,'数据中心'));
    hosIdx = find(strcmp(sys.nodeType,'医院'));

    % 全部失负荷时的基准
    totalMWh = sum(sys.Pload_kW(2:end)) / 1000 * cfg.T;

    for k = 1:K
        names{k} = results(k).name;
        if ~succ(k), continue; end

        ens(k)  = results(k).ENS;
        loss(k) = results(k).ENS_w;
        salvage_MWh(k) = totalMWh - ens(k);
        salvage_USD(k) = sys_avg_VOLL(sys) * salvage_MWh(k);  % 用平均 VOLL 折算

        a = results(k).alpha;
        dcR  = mean(a(dcIdx, :), 1);
        hosR = mean(a(hosIdx,:), 1);
        dcT(k)  = firstRec(dcR);
        hosT(k) = firstRec(hosR);
    end

    % 用 uitable 画表
    fig = figure('Position',[50 50 1500 420]); axis off;
    data = [ens, loss/1000, salvage_MWh, salvage_USD/1000, dcT, hosT];
    colNames = {'ENS(MWh)','损失(千$)','挽回(MWh)','挽回(千$)','DC恢复(时段)','医院恢复(时段)'};
    t = uitable(fig, 'Data', data, 'ColumnName', colNames, ...
                'RowName', names, 'Position', [20 40 1460 340], ...
                'FontSize', 11);
    title('5 种策略综合对比表（NaN = 求解失败）', ...
          'FontSize', 15, 'FontWeight', 'bold');

    exportgraphics(fig, fullfile(saveDir,'fig6_summary_table.png'), ...
                   'Resolution', 300);
    fprintf('    → 保存: fig6_summary_table.png\n');

    %% ============ 命令行表格 ============
    fprintf('\n========= 综合对比表 =========\n');
    fprintf('%-38s | %8s | %10s | %10s | %10s\n', ...
            '场景','ENS(MWh)','损失(千$)','挽回(MWh)','挽回(千$)');
    for k = 1:K
        if succ(k)
            fprintf('%-38s | %8.4f | %10.2f | %10.2f | %10.2f\n', ...
                    names{k}, ens(k), loss(k)/1000, salvage_MWh(k), salvage_USD(k)/1000);
        else
            fprintf('%-38s | %8s | %10s | %10s | %10s\n', ...
                    names{k}, 'N/A', 'N/A', 'N/A', 'N/A');
        end
    end
end

function t0 = firstRec(series)
    idx = find(series < 1e-3, 1);
    if isempty(idx), t0 = NaN; else, t0 = idx - 1; end
end

function v = sys_avg_VOLL(sys)
    % 计算全网平均 VOLL（用于"挽回金额"粗略折算）
    P = sys.Pload_kW;
    P(sys.root) = 0;
    v = sum(sys.VOLL .* P) / max(sum(P), 1e-6);
end