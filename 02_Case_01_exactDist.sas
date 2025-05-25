/**********************************************************************
 * Case 1: Group Life Insurance;
 * Jose Enrique Perez ;
 * Licenciatura en Actuaría;
 * Facultad de Negocios. Universidad La Salle México;
 **********************************************************************/

* Number of risk units in the individual risk model;
%let ne=14;
%put &=ne.;
* Gross premium;
%let G = 2947.72;

%macro allcombinatios(n=);
/*
Purpose: To calculate all the states of the world for each employee 
n: number of employees
*/
	* i is the number of deaths;
	%do i=1 %to &n.;
		* Computing the number of combinations;
		data _null_;
			call symputx('nc',comb(&n.,&i.));
		run;
		%put &=nc.;
		* Generating the combinations;
		proc plan seed=2025;
			factors iter=&nc. ordered id_employee = &i. of &n. comb / noprint;
			output out=comb_&i.;
		run;
		* Saving the results;
		data id_comb_&i.;			
			number_deaths=&i.;
			is_dead=1;
			set comb_&i.;
		run;
	%end;
	* Appending the results;
	data death;
		set id_comb_:;
	run;
	* Delete unuseful data sets;
	proc datasets lib=work nolist;
		delete id_comb_: comb_:;
	run;
	* i is the number of survivals;
	%do i=1 %to &n.;
		* Computing the number of combinations;
		data _null_;
			call symputx('nc',comb(&n.,&i.));
		run;
		%put &=nc.;
		* Generating the combinations;
		proc plan seed=2025;
			factors iter=&nc. ordered id_employee = &i. of &n. comb / noprint;
			output out=comb_&i.;
		run;
		* Saving the results;
		data id_comb_&i.;			
			number_deaths=&n.-&i.;
			is_dead=0;
			set comb_&i.;
			iter=&nc.-iter+1;
		run;
	%end;
	* Appending the results;
	data alive;
		set id_comb_:;
	run;
	* Delete unuseful data sets;
	proc datasets lib=work nolist;
		delete id_comb_: comb_:;
	run;
	* Appending the deaths and alives employees for each state of the world;
	data comb;
		set death alive;
	run;
	* Ordering the data set to understand better the states of the world;
	proc sort data=comb;
		by number_deaths iter;
	run;
	* Delete unuseful data sets;
	proc datasets lib=work nolist;
		delete death alive;
	run;

%mend;

* Execute the macro;
%allcombinatios(n=&ne.);

/*
proc print data=comb noobs;
run;
*/
* Create the matrix of the parameters for each employee;
proc iml;
	
	* Number of risk units in the individual risk model;
	n=&ne.;
	* Matrix for the parameters;
	par=j(n,4,.);
	* ID employee;
	par[,1]=t(do(1,n,1));
	* Benefits;
	par[,2]={15000,16000,20000,28000,31000,18000,26000,24000,60000,14000,17000,19000,30000,55000};
	*par[,2]={15000,16000,20000};
	* Mortality rates;
	par[,3]={0.000965,0.001069,0.001252,0.001434,0.001505,0.003751,0.004037,0.004698,0.017778,0.000884,0.001031,0.001201,0.002078,0.007682};
	*par[,3]={0.000965,0.001069,0.001252};
	* Survival rates;
	par[,4]=1-par[,3];
	print par;
	varNames={"id_employee","benefit","q","p"};
	* Sending the results to a dataset;
	create par from par[colname=varNames];
	append from par;
	close par;	
quit;

* Joining the states of the world with the parameters;
proc sql;
	create table full_comb as
	select
	b.*
	, case is_dead
	when 1 then benefit
	when 0 then 0 
	else 0 end as claim
	, case is_dead
	when 1 then q
	when 0 then p 
	else 0 end as prob
	from work.par a right join work.comb b on (a.id_employee = b.id_employee)
	order by number_deaths, iter
	; 
quit;

* Computing the total claim and its probability for each state of the world;
proc sql;
	create table full_comb2 as
	select
	number_deaths
	, iter
	, sum(claim) as S
	, EXP(SUM(LOG(prob))) as prob
	from full_comb
	group by number_deaths, iter
	;
quit;

* Grouping by total claim and its probability;
proc sql;
	create table full_comb3 as
	select
	S format nlnum16.2 label="Total claim in the group life insurance"
	, sum(prob) as prob format 16.6 label="Probability"
	from full_comb2
	group by S
	order by S
	;
quit;

title "Distribution of the aggregate loss (S)";
proc print data=full_comb3 noobs;
run;
title;

title "Validation of the Distribution of the aggregate loss (S)";
proc means data=full_comb2 sum min max;
	var prob;
run;
title;

title "Distribution of the aggregate loss (S)";
proc sgplot data=full_comb3;
	needle x=S y=prob;
run;
title;

title "Probability of losing money in this contract";
proc sql;
	select sum(prob) as "P[S>G]"n
	from full_comb3
	where S > &G.;
quit;
title;
