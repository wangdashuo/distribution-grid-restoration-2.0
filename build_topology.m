function [paths, downstream] = build_topology(sys)
    nN = sys.nNode;  nB = sys.nBranch;
    paths = cell(nN,1);  paths{sys.root} = [];
    visited = false(nN,1);  visited(sys.root) = true;
    queue = sys.root;
    while ~isempty(queue)
        j = queue(1); queue(1) = [];
        for e = 1:nB
            if sys.isTie(e), continue; end
            if sys.from(e) == j && ~visited(sys.to(e))
                k = sys.to(e);
                paths{k} = [paths{j}, e];
                visited(k) = true;
                queue(end+1) = k; %#ok<AGROW>
            end
        end
    end
    downstream = cell(nB,1);
    for e = 1:nB
        if sys.isTie(e), downstream{e} = []; continue; end
        ds = [];
        for j = 1:nN
            if ~isempty(paths{j}) && any(paths{j} == e)
                ds(end+1) = j; %#ok<AGROW>
            end
        end
        downstream{e} = ds;
    end
end