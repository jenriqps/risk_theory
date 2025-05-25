/**********************************************************************
 * Case 1: Group Life Insurance;
 * Jose Enrique Perez ;
 * Licenciatura en Actuaría;
 * Facultad de Negocios. Universidad La Salle México;
 **********************************************************************/


* Number of simulations;
%let m = 1000000;
* Gross premium;
%let G = 2947.72;


proc iml;
	* Fix the random seed to replicate results between users and accross time;
	call randseed(2025);
	
	* Number of risk units in the individual risk model;
	n=14;
	* Matrix for the parameters;
	par=j(n,2,.);
	* Benefits;
	par[,1]={15000,16000,20000,28000,31000,18000,26000,24000,60000,14000,17000,19000,30000,55000};
	* Mortality rates;
	par[,2]={0.000965,0.001069,0.001252,0.001434,0.001505,0.003751,0.004037,0.004698,0.017778,0.000884,0.001031,0.001201,0.002078,0.007682};
	* Matrix for the Bernoulli simulations;
	ber = j(n,&m.,.);
	* Matrix for the loss simulations;
	X = j(n,&m.,.);
	print(par);
	* Simulating the deaths of the 14 employees;
	do i=1 to n;
		aux=j(1,&m.,.);
		q = par[i,2];
		call randgen(aux,"Bernoulli",q);
		ber[i,]=aux;
	end;
	* Simulating the losses; 
	X = par[,1]#ber;
	S = X[+,];
	* Sending the results to a dataset;
	create aggclaim var{S};
	append;
	close aggclaim;

quit;

* Changing formats and labels so the data set looks better;
proc datasets lib=work nodetails nolist;
	modify aggclaim;
	label
	S="Total claim in the group life insurance"; 
	format
	S nlnum16.2;
quit;

title "Distribution of the aggregate loss (S)";
proc sgplot data=work.aggclaim;
	histogram S;
	density S / type=normal transparency=0.7;
	xaxis grid;
	yaxis grid;
run;
title;

proc freq data=work.aggclaim;
run;


title "Are the simulated mean, variance and skewness similar to the previous results?";
proc means data=work.aggclaim mean var skewness;
	var S;
run;
title;

title "Probability of losing money in this contract";
proc sql;
	select count(*)/&m. as "P[S>G]"n
	from work.aggclaim
	where S > &G.;
quit;
title;

