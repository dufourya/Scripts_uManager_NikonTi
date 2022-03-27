function f_name = getFunctionName()
    [st,~] = dbstack();
    
    % get name of funciton that called this one.
    f_name = st(2).name;
end