function fig4_economic_salvage(results, sys, cfg, saveDir)
% FIG4_ECONOMIC_SALVAGE  分档 VOLL 下的经济损失与挽回分析
%                        （5 场景，NaN 安全）

    style_poster();
    K = numel(results);
    shortNames = {'S1','S2','S3','S4','S5'};

    dcIdx  = find(strcmp(sys.nodeType,'数据中心'));
    hosIdx = find(strcmp(sys.nodeType,'医院'));

    MWh_total = zeros(K,1);  MWh_DC = zeros(K,1);  MWh_Hos = zeros(K,1);
    MWh_Ind   = zeros(K,1);  MWh_Res = zeros(K,1); lossUSD = zeros(K,1);

    for k = 1:K
        if ~results(k).success
            MWh_total(k) = NaN;  lossUSD(k) = NaN;
            MWh_DC(k) = NaN;  MWh_Hos(k) = NaN;
            MWh_Ind(k) = NaN;  MWh_Res(k) = NaN;
            continue;
        end
        a = results(k).alpha;
        for t = 1:cfg.T
            for j = 2:sys.nNode
                MWh_j = sys.Pload_kW(j)/1000 * a(j,t) * cfg.dt;
                MWh_total(k) = MWh_total(k) + MWh_j;
                lossUSD(k)   = lossUSD(k)   + sys.VOLL(j) * MWh_j;
                if ismember(j, dcIdx)
                    MWh_DC(k)  = MWh_DC(k)  + MWh_j;
                elseif ismember(j, hosIdx)
                    MWh_Hos(k) = MWh_Hos(k) + MWh_j;
                elseif sys.VOLL(j) >= 1000
                    MWh_Ind(k) = MWh_Ind(k) + MWh_j;
                else
                    MWh_Res(k) = MWh_Res(k) + MWh_j;
                end
            end
        end
    end

    succ = [results.success];

    % 基准：全部失负荷时的经济总损失（只依赖算例，与求解无关）
    USD_full = 0;
    for j = 2:sys.nNode
        USD_full = USD_full + sys.VOLL(j) * sys.Pload_kW(j)/1000 * cfg.T;
    end

    %% ============ 画图 ============
    fig = figure('Position',[50 50 1800 560]);

    % ---------- (a) 总经济损失 ----------
    subplot(1,3,1);
    b = bar(lossUSD/1000, 'FaceColor','flat','EdgeColor','k','LineWidth',1.2);
    for k = 1:K
        if succ(k)
            b.CData(k,:) = [0.85 0.20 0.20];
        else
            b.CData(k,:) = [0.60 0.60 0.60];
        end
    end
    set(gca,'XTickLabel', shortNames,'FontSize',13);
    ylabel('经济损失 (千美元)','FontSize',14);
    title('(a) 总经济损失','FontSize',15);
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

    % ---------- (b) 分类别失电构成 ----------
    subplot(1,3,2);
    M = [MWh_DC, MWh_Hos, MWh_Ind, MWh_Res];
    bar(M, 'stacked','EdgeColor','k');
    set(gca,'XTickLabel', shortNames,'FontSize',13);
    ylabel('失电量 (MWh)','FontSize',14);
    title('(b) 分类别失电构成','FontSize',15);
    legend({'数据中心','医院','大工业','普通负荷'}, ...
           'Location','northeast','FontSize',10);
    grid on;
    % 标注失败场景
    for k = 1:K
        if ~succ(k)
            yl2 = ylim();
            text(k, yl2(2)*0.5, 'N/A', 'HorizontalAlignment','center', ...
                 'FontSize',11,'Color','r','FontWeight','bold');
        end
    end

    % ---------- (c) 挽回金额 ----------
    subplot(1,3,3);
    if succ(1) && lossUSD(1) > 1e-6 && USD_full > 1e-6
        salvage = (USD_full - lossUSD) / 1000;
        salvage(~succ) = NaN;
        b3 = bar(salvage, 'FaceColor',[0.20 0.70 0.35],'EdgeColor','k','LineWidth',1.2);
        for k = 1:K
            if succ(k)
                text(k, salvage(k)*1.03, ...
                     sprintf('%.1f\n(%.1f%%)', salvage(k), ...
                     salvage(k)/(USD_full/1000)*100), ...
                     'HorizontalAlignment','center','FontSize',10, ...
                     'FontWeight','bold');
            end
        end
    else
        bar(zeros(K,1));
        text(K/2, 0.5, '基准无效，无法计算挽回金额', ...
             'HorizontalAlignment','center','FontSize',12,'Color','r', ...
             'BackgroundColor',[1 1 1 0.9], 'Margin', 3);
    end
    set(gca,'XTickLabel', shortNames,'FontSize',13);
    ylabel('挽回 (千美元)','FontSize',14);
    title('(c) 挽回经济损失','FontSize',15);
    grid on;

    sgtitle(sprintf('分档 VOLL 经济性（基准失电损失 %.0f k$）', USD_full/1000), ...
            'FontSize',16,'FontWeight','bold');

    exportgraphics(fig, fullfile(saveDir,'fig4_economic_salvage.png'), 'Resolution', 300);
    fprintf('    → 保存: fig4_economic_salvage.png\n');

    %% ============ 命令行明细 ============
    fprintf('\n======= 经济性对比 =======\n');
    fprintf('%-6s | %10s | %14s | %10s | %10s\n', ...
            '场景','总MWh','损失(千$)','DC(MWh)','医院(MWh)');
    for k = 1:K
        if succ(k)
            fprintf('%-6s | %10.3f | %14.2f | %10.4f | %10.4f\n', ...
                    shortNames{k}, MWh_total(k), lossUSD(k)/1000, ...
                    MWh_DC(k), MWh_Hos(k));
        else
            fprintf('%-6s | %10s | %14s | %10s | %10s\n', ...
                    shortNames{k}, 'N/A','N/A','N/A','N/A');
        end
    end

    if succ(1) && succ(4) && lossUSD(1) > 1e-6
        fprintf('S1→S4 损失下降: %.1f%%\n', ...
                (lossUSD(1)-lossUSD(4))/lossUSD(1)*100);
    else
        fprintf('S1 或 S4 无效，无法计算下降比例\n');
    end
end