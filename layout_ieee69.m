function xy = layout_ieee69()
    nN = 69;  xy = zeros(nN, 2);
    for i = 1:27,  xy(i,:) = [i, 0];        end
    for i = 28:52, xy(i,:) = [i-25, -3];    end
    for i = 53:65, xy(i,:) = [i-44, 2];     end
    xy(66,:) = [11, -1];  xy(67,:) = [11, -2];
    xy(68,:) = [12, -1];  xy(69,:) = [12, -2];
end