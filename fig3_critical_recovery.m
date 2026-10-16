function fig3_critical_recovery(results, sys, cfg, saveDir)
% FIG3_CRITICAL_RECOVERY  数据中心/医院恢复时序

    style_poster(); C = poster_colors();
    T = cfg.T; K = numel(results);

    dcIdx  = find(strcmp(sys.nodeType,'数据中心'));
    hosIdx = find(strcmp(sys.nodeType,'医院'));

    dcR = ones(T+1,K); hosR = ones(T+1,K);
    for k = 1:K
        a = results(k).alpha;
        for t = 1:T
            dcR(t+1,k)  = mean(a(dcIdx, t));
            hosR(t+1,k) = mean(a(hosIdx, t));
        end
    end

    cols = {C.S1, C.S2, C.S3, C.S4, C.S5};
    ls   = {'-o','-s','-^','-d', '-p'};

    fig = figure('Position',[50 50 1500 550]);

    subplot(1,2,1);
    hold on;
    for k = 1:K
        plot(0:T, dcR(:,k), ls{k}, 'Color',cols{k}, ...
             'LineWidth',2.5,'MarkerSize',10,'MarkerFaceColor',cols{k});
    end
    xlabel('时段 t (t=0 为故障发生)','FontSize',14);
    ylabel('平均失负荷比例','FontSize',14);
    title(sprintf('数据中心 (节点 %s) 恢复曲线',mat2str(dcIdx')),'FontSize',15);
    legend({results.name},'Location','northeast','FontSize',11);
    grid on; ylim([-0.05 1.1]); xticks(0:T);

    subplot(1,2,2);
    hold on;
    for k = 1:K
        plot(0:T, hosR(:,k), ls{k}, 'Color',cols{k}, ...
             'LineWidth',2.5,'MarkerSize',10,'MarkerFaceColor',cols{k});
    end
    xlabel('时段 t','FontSize',14);
    ylabel('平均失负荷比例','FontSize',14);
    title(sprintf('医院 (节点 %s) 恢复曲线',mat2str(hosIdx')),'FontSize',15);
    legend({results.name},'Location','northeast','FontSize',11);
    grid on; ylim([-0.05 1.1]); xticks(0:T);

    sgtitle('关键负荷恢复速度对比','FontSize',16,'FontWeight','bold');
    exportgraphics(fig, fullfile(saveDir,'fig3_critical_recovery.png'), 'Resolution', 300);
end