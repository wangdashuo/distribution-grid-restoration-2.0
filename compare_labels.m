function compare_labels(sys, cfg)
% 对比启发式标签与 MILP 标签，检验启发式是否"丢信息"
    rng(cfg.seed);

    fprintf('\n===== 标签对比（启发式 vs MILP）=====\n');

    [paths, downstream] = build_topology(sys);
    nB = sys.nBranch;

    sc = struct('useReliability',true,'useImportance',true,'useAI',false);

    % 基准启发式
    base = 0;
    for e = 1:nB
        if sys.isTie(e), continue; end
        ds = downstream{e};
        if ~isempty(ds)
            base = max(base, sum(sys.wImp(ds).*sys.Pload_kW(ds)));
        end
    end
    base = max(base, 1e-6);

    fprintf('%-14s %12s %12s %12s\n','场景/线路','启发式','MILP-tFix','MILP标签');
    for it = 1:5
        fault = generate_fault_scenario(sys, cfg);
        r = solve_restoration(fault, zeros(nB,1), sys, cfg, sc);
        for e = find(fault)'
            ds = downstream{e};
            if isempty(ds)
                heu = 0;
            else
                heu = sum(sys.wImp(ds).*sys.Pload_kW(ds)) / base;
            end
            tFix = find(r.s(e,:)>0.5, 1);
            if isempty(tFix)
                lbl = 0;
            else
                lbl = (cfg.T - tFix + 1) / cfg.T;
            end
            fprintf('场景%-3d 线路%-3d %12.3f %12s %12.3f\n', ...
                    it, e, heu, mat2str(tFix), lbl);
        end
    end
end