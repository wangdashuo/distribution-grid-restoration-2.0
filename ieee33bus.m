function sys = ieee33bus()
    branchData = [
        1  2  0.0922 0.0470;   2  3  0.4930 0.2511;   3  4  0.3660 0.1864;
        4  5  0.3811 0.1941;   5  6  0.8190 0.7070;   6  7  0.1872 0.6188;
        7  8  1.7114 1.2351;   8  9  1.0300 0.7400;   9 10  1.0400 0.7400;
       10 11  0.1966 0.0650;  11 12  0.3744 0.1238;  12 13  1.4680 1.1550;
       13 14  0.5416 0.7129;  14 15  0.5910 0.5260;  15 16  0.7463 0.5450;
       16 17  1.2890 1.7210;  17 18  0.7320 0.5740;   2 19  0.1640 0.1565;
       19 20  1.5042 1.3554;  20 21  0.4095 0.4784;  21 22  0.7089 0.9373;
        3 23  0.4512 0.3083;  23 24  0.8980 0.7091;  24 25  0.8960 0.7011;
        6 26  0.2030 0.1034;  26 27  0.2842 0.1447;  27 28  1.0590 0.9337;
       28 29  0.8042 0.7006;  29 30  0.5075 0.2585;  30 31  0.9744 0.9630;
       31 32  0.3105 0.3619;  32 33  0.3410 0.5302;
    ];
    loadData = [
          0    0;   100   60;    90   40;   120   80;    60   30;
         60   20;   200  100;   200  100;    60   20;    60   20;
         45   30;    60   35;    60   35;   120   80;    60   10;
         60   20;    60   20;    90   40;    90   40;    90   40;
         90   40;    90   40;    90   50;   420  200;   420  200;
         60   25;    60   25;    60   20;   120   70;   200  600;
        150   70;   210  100;    60   40;
    ];
    sys.nNode = 33;  sys.nBranch = size(branchData,1);
    sys.from = branchData(:,1);  sys.to = branchData(:,2);
    sys.R = branchData(:,3);     sys.X = branchData(:,4);
    sys.isTie = false(sys.nBranch,1);
    sys.Pload_kW = loadData(:,1);  sys.Qload_kVar = loadData(:,2);
    sys.root = 1;

    sys.wImp = ones(sys.nNode,1);
    sys.wImp(24) = 10;  sys.wImp(25) = 10;
    sys.wImp(30) = 8;   sys.wImp(31) = 8;
    sys.wImp(sys.Pload_kW > 100) = max(sys.wImp(sys.Pload_kW > 100), 3);
    sys.wImp(sys.root) = 0;

    sys.nodeType = repmat({'普通负荷'}, sys.nNode, 1);
    sys.nodeType(24) = {'数据中心'};  sys.nodeType(25) = {'数据中心'};
    sys.nodeType(30) = {'医院'};      sys.nodeType(31) = {'医院'};

    Prel = sys.Pload_kW / max(sys.Pload_kW);
    sys.wRel = 1 + 2 * Prel.^0.5;  sys.wRel(sys.root) = 0;

    VOLL = 50 * ones(sys.nNode, 1);
    VOLL(24) = 10000;  VOLL(25) = 10000;
    VOLL(30) = 5000;   VOLL(31) = 5000;
    VOLL(sys.Pload_kW > 100) = max(VOLL(sys.Pload_kW > 100), 1000);
    VOLL(sys.root) = 0;
    sys.VOLL = VOLL;
end