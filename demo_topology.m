%% ============ 单线图演示 ============
clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

cfg = config();
sys = ieee69bus();
rng(cfg.seed);

% ---------- 图1：干净单线图（带全部标签）----------
plot_topology(sys, [], struct( ...
    'showLabels', true, ...
    'titleStr',   '（1）IEEE 69 节点系统原始单线图'));

% ---------- 图2：含故障高亮（不显示全部标签）----------
fault = generate_fault_scenario(sys, cfg);
fprintf('本场景故障线路: %s\n', mat2str(find(fault)'));

% plot_topology(sys, fault, struct( ...
%     'showLabels', false, ...
%     'titleStr',   sprintf('（2）故障场景（红线加粗: %s）', ...
%                           mat2str(find(fault)'))));

plot_topology(sys, fault, struct('showLabels',true))

% ---------- 图3：带AI修复时序标注 ----------
% 若你已训练 model，可在这里跑一次求解，把修复时段标在图上
% 下面仅演示"维修班组色块"占位（可选）