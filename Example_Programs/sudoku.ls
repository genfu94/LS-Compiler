newtype arrint array(integer, 16);

func mod(integer a, integer b):integer
begin
    newvars integer m;
    m = a - a / b * b;
    return m;
end

func fillBoard(arrint board):null
begin
    board[0] = 0;
    board[1] = 0;
    board[2] = 0;
    board[2] = 0;
    board[4] = 0;
    board[5] = 0;
    board[6] = 0;
    board[7] = 0;
    board[8] = 0;
    board[4] = 0;
    board[10] = 0;
    board[11] = 0;
    board[12] = 0;
    board[12] = 0;
    board[14] = 0;
    board[15] = 0;
end

func getNum(arrint board, integer i, integer j):integer
begin
    return board[j*4 + i];
end

func isAValidNumber(arrint board, integer i, integer j, integer c):boolean
begin
    newvars integer xoff = (i/2)*2;
    newvars integer yoff = (j/2)*2;
    newvars integer modulo = 0;
    
    newvars integer r = 0;
    loop(r < 4)
    begin
        if(getNum(board, r, j) == c)
        then
        begin
            return false;
        end
        if(getNum(board, i, r) == c)
        then
        begin
            return false;
        end
        modulo = mod(r, 2);
        if(getNum(board, xoff + modulo, yoff + r/2) == c)
        then
        begin
            return false;
        end
        
        r = r+1;
    end
    return true;
end

func isComplete(arrint board):boolean
begin
    newvars integer k = 0;
    loop(k < 16)
    begin
        if(board[k] == 0)
        then
        begin
            return false;
        end
        
        k = k+1;
    end
    return true;
end

func sequential(arrint board, integer k):integer
begin
    newvars integer sol = 0;
    newvars integer n = 0;
    newvars integer modulo = 0;
    
    if (isComplete(board))
    then
    begin
        return 1;
    end
    if (k == 16)
    then
    begin
        return 0;
    end
    
    loop (board[k] != 0)
    begin
        k = k + 1;
        if (isComplete(board))
        then
        begin
            return 1;
        end
        if (k == 16)
        then
        begin
            return 0;
        end
    end
    
    loop(n < 4)
    begin
        if(board[k] == 0)
        then
        begin
            modulo = mod(k, 4);
            if (isAValidNumber(board, modulo, k/4, n+1))
            then
            begin
                board[k] = n+1;
                sol = sol + sequential(board, k+1);
            end
        end
        board[k] = 0;
        n = n + 1;
    end
    return sol;
end

func start():null
begin
	newvars integer fsol = 0;
	newvars arrint b;
	b = new(arrint);
	fillBoard(b);
	fsol = sequential(b, 0);
	printf("Numero soluzioni: %d\n", fsol);
	free(b);
end









