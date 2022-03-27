function [row_shift,col_shift] = dftregistermicroscope(buf1ft,buf2ft,maxshift)

[m,n]=size(buf1ft);

maxshift = max(0,min([maxshift m n]));

CC = ifft2(buf1ft.*conj(buf2ft));

CC(:,(maxshift+1):end-maxshift) = -Inf;
CC((maxshift+1):end-maxshift,:) = -Inf;

[max1,loc1] = max(CC);
[~,cloc] = max(max1);
rloc=loc1(cloc);

if rloc > fix(m/2)
    row_shift = rloc - m - 1;
else
    row_shift = rloc - 1;
end

if cloc > fix(n/2)
    col_shift = cloc - n - 1;
else
    col_shift = cloc - 1;
end

return