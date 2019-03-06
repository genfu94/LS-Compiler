newtype Time record (integer seconds, integer minutes, integer hours);

func differenceBetweenTimePeriod(Time start, Time stop):Time
begin
	newvars Time out = new(Time);
	
    if(stop.seconds > start.seconds) then begin
        start.minutes = start.minutes - 1;
        start.seconds = start.seconds + 60;
    end
    
    out.seconds = start.seconds - stop.seconds;
    
    if(stop.minutes > start.minutes) then begin
        start.hours = start.hours - 1;
        start.minutes = start.minutes + 60;
    end
    
    out.minutes = start.minutes - stop.minutes;
	out.hours = start.hours - stop.hours;
    
    return out;
end

func start():null
begin
    newvars Time startTime = new(Time), stopTime = new(Time), diff = new(Time);
    printf("Enter start time: \n");
	printf("Enter hours, minutes and seconds respectively: ");
	scanf("%d %d %d", startTime.hours, startTime.minutes, startTime.seconds);
    printf("Enter stop time: \n");
    printf("Enter hours, minutes and seconds respectively: ");
    scanf("%d %d %d", stopTime.hours, stopTime.minutes, stopTime.seconds);

    diff = differenceBetweenTimePeriod(startTime, stopTime);

    printf("\nTIME DIFFERENCE: %d:%d:%d - ", startTime.hours, startTime.minutes, startTime.seconds);
    printf("%d:%d:%d ", stopTime.hours, stopTime.minutes, stopTime.seconds);
    printf("= %d:%d:%d\n", diff.hours, diff.minutes, diff.seconds);
    
end
