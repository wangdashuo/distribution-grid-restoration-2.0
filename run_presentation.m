function run_presentation(results, sys, cfg, testFault, wAI, model)
% RUN_PRESENTATION  统一入口：加载 results.mat → 出所有图（含 3D 主视觉）
%
% 用法:
%   >> run_presentation
%   >> run_presentation(results, sys, cfg, testFault, wAI, model)

% ============ 1. 定位 results.mat ============
here = fileparts(mfilename('fullpath'));
cand = {};
cand{end+1} = fullfile(pwd, 'results.mat');

p = here;
for lvl = 1:4
    cand{end+1} = fullfile(p, 'results.mat');                 %#ok<AGROW>
    cand{end+1} = fullfile(p, 'restoration', 'results.mat');  %#ok<AGROW>
    parent = fileparts(p);
    if strcmp(parent, p), break; end
    p = parent;
end
cand = unique(cand);

% ============ 2. 加载或接收数据 ============
if nargin == 0
    matFile = '';
    for i = 1:numel(cand)
        if isfile(cand{i}), matFile = cand{i}; break; end
    end
    if isempty(matFile)
        fprintf('\n[错误] 找不到 results.mat\n已尝试:\n');
        for i = 1:numel(cand), fprintf('  %s\n', cand{i}); end
        error('未找到 results.mat');
    end
    fprintf('加载: %s\n', matFile);
    S = load(matFile, 'results', 'sys', 'cfg', 'testFault', 'wAI', 'model');
    results=S.results; sys=S.sys; cfg=S.cfg;
    testFault=S.testFault; wAI=S.wAI; model=S.model;
elseif nargin < 6
    error(['输入参数不足:\n' ...
        '  run_presentation\n' ...
        '  run_presentation(results,sys,cfg,testFault,wAI,model)']);
end

% ============ 3. 输出目录 ============
saveDir = fullfile(here, 'output');
if ~exist(saveDir, 'dir'), mkdir(saveDir); end
fprintf('\n输出目录: %s\n', saveDir);

% ============ 4. 依次出图 ============
fprintf('\n[1/8] 系统 + 故障拓扑\n');
fig1_network(sys, testFault, saveDir);

fprintf('[2/8] ENS 对比\n');
fig2_ens_compare(results, saveDir);

fprintf('[3/8] 关键负荷恢复\n');
fig3_critical_recovery(results, sys, cfg, saveDir);

fprintf('[4/8] 经济性对比\n');
fig4_economic_salvage(results, sys, cfg, saveDir);

fprintf('[5/8] 抢修甘特图\n');
fig5_crew_timeline(results, sys, cfg, saveDir);

fprintf('[6/8] 汇总表\n');
fig6_summary_table(results, sys, cfg, saveDir);

fprintf('[7/8] 求解时间对比\n');
fig7_runtime(results, sys, cfg, saveDir);

fprintf('[8/9] 3D 立体主视觉\n');
try fig8_3d_hero(sys, testFault, saveDir);
catch ME, fprintf('    [!] fig8 失败: %s\n', ME.message); end

fprintf('[9/9] 分类别失电量\n');
fig9_critical_ens(results, sys, cfg, saveDir);

fprintf('\n全部完成！保存于:\n  %s\n', saveDir);
end