function xy = layout_ieee33()
    xy = zeros(33, 2);
    for i = 1:18,  xy(i,:) = [i, 0];        end
    for i = 19:22, xy(i,:) = [i-17, -2];    end
    for i = 23:25, xy(i,:) = [i-20, 2];     end
    for i = 26:33, xy(i,:) = [i-20, -4];    end
end