newtype TenIntArr array(integer, max);
newvars integer max = 10;
newvars TenIntArr a = new(TenIntArr),  b = new(TenIntArr);

func merging(integer low, integer mid, integer high):null
begin
	newvars integer l1 = low, l2 = mid + 1, i = low;
	
	loop(l1 <= mid && l2 <= high) begin
		if(a[l1] <= a[l2]) then begin
			b[i] = a[l1];
			l1 = l1 + 1;
		end else begin
			b[i] = a[l2];
			l2 = l2 + 1;
		end
		i = i + 1;
	end
   
	loop(l1 <= mid) begin
		b[i] = a[l1];
		i = i+1;
		l1 = l1 + 1;
	end

	loop(l2 <= high) begin
		b[i] = a[l2];
		i = i+1;
		l2 = l2 + 1;
	end
	
	i = low;
	loop(i <= high) begin
		a[i] = b[i];
		i = i + 1;
	end
end

func sort(integer low, integer high):null
begin
   newvars integer mid;
   
   if(low < high) then begin
      mid = (low + high) / 2;
      sort(low, mid);
      sort(mid+1, high);
      merging(low, mid, high);
   end else begin
      return null;
   end
end

func start():null
begin
	newvars integer i;
	i = 0;
	a[0] = 10;
	a[1] = 14;
	a[2] = 7;
	a[3] = 4;
	a[4] = 26;
	a[5] = 19;
	a[6] = 5;
	a[7] = 11;
	a[8] = 23;
	a[9] = 17;
	printf("List before sorting\n");
	loop(i <= max) begin
		printf("%d ", a[i]);
		i = i + 1;
	end
	
	sort(0, max);

	printf("\nList after sorting\n");
   
    i = 0;
	loop(i <= max) begin
		printf("%d ", a[i]);
		i = i + 1;
	end
end
