function model = train_priority_model(X, Y)
    if isempty(X) || size(X,1) < 3, error('训练样本不足'); end
    mu    = mean(X,1);
    sigma = std(X,0,1) + 1e-6;
    Xn    = (X - mu) ./ sigma;
    Xn    = [ones(size(Xn,1),1), Xn];
    lambda = 0.1;  d = size(Xn,2);
    theta = (Xn'*Xn + lambda*eye(d)) \ (Xn'*Y);
    model.theta = theta;  model.mu = mu;  model.sigma = sigma;
    rmse = sqrt(mean((Xn*theta - Y).^2));
    fprintf('  [AI训练] 样本=%d, RMSE=%.4f\n', size(X,1), rmse);
end