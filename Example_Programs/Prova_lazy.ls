func f():integer
begin
	printf("Ho eseguito la funzione associata all'assegnamento lazy\n");
	return 5;
end

func start():null
begin
	newvars integer k = 5;
	k ?= 10 +f();
	printf("%d", k);
end
