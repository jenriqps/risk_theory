/**********************************************************************
 * Case 1: Group Life Insurance;
 * Jose Enrique Perez ;
 * Licenciatura en Actuaría;
 * Facultad de Negocios. Universidad La Salle México;
**********************************************************************/



/* Importaciones */
FILENAME REFFILE '/export/viya/homes/perez-jose@lasallistas.org.mx/Risk_Theory/RR8AUISINS009920231231.txt';

PROC IMPORT DATAFILE=REFFILE
	DBMS=DLM
	OUT=MYLIB.RR8AUISINS replace;
	DELIMITER="|";
	GETNAMES=NO;
	DATAROW=1;
RUN;
PROC CONTENTS DATA=MYLIB.RR8AUISINS; RUN;
/* Selección de variables relevanetes y transformaciones */
data MYLIB.RR8AUISINS_2(drop=var: month day year);
	label 
	n_poliza="Número de Póliza"
	n_siniestro="Número de Siniestro"
	f_ocurr_sin="Fecha de Ocurrencia del Siniestro";
	format f_ocurr_sin date9. m_siniestro dollar20.2;
	set MYLIB.RR8AUISINS;
	n_poliza=var1;
	n_siniestro=var2;
	month=substr(compress(var3),5,2);
	day=substr(compress(var3),7,2);
	year=substr(compress(var3),1,4);
	f_ocurr_sin=mdy(input(month,best12.),input(day,best12.),input(year,best12.));
	m_siniestro=var8;
run;


/*************************************/

proc sort data=MYLIB.RR8AUISINS_2 out=Work.preProcessedData;
by f_ocurr_sin;
run;
 
proc timedata data=Work.preProcessedData seasonality=12 out=WORK._tsoutput;
id f_ocurr_sin interval=month setmissing=missing;
var m_siniestro / accumulate=n transform=none;
run;
 
data mylib.tsPrep_freq(drop=m_siniestro);
set WORK._tsoutput;
format n_siniestro 3.;
n_siniestro=m_siniestro;
run;
 
proc delete data=Work.preProcessedData;
run;
 
proc delete data=WORK._tsoutput;
run;

/****************/

/* Estimating the parameters of the Poisson distribution */
ods output FitSummary=mylib.fs_poisson;
proc countreg data=mylib.tsPrep_freq corrb;
	model n_siniestro= / dist=poisson;
	store mylib.cntStr_Poisson;
	performance details;
run;


/* Estimating the parameters of the negative binomial regression model that uses a quadratic variance function */
ods output FitSummary=mylib.fs_nb2;
proc countreg data=mylib.tsPrep_freq corrb;
	model n_siniestro= / dist=negbin(p=2);
	store mylib.cntStr_nb2;	
	performance details;
run;


* Estimation of the severity distribution ;
proc severity data= MYLIB.RR8AUISINS_2 print=all outest=mylib.outest outmodelinfo=mylib.omi outstat=mylib.outstat;
   loss m_siniestro;
   dist _PREDEFINED_;
   nloptions maxiter=100000;
   outscorelib outlib=mylib.score_sev commonpackage;
run;


proc hpcdm countstore=mylib.cntStr_Poisson severityest=mylib.outest
           seed=13579 nreplicates=100000 print=(summarystatistics percentiles);
   severitymodel weibull;
   output out=mylib.aggregateLossSample samplevar=aggloss;
   outsum out=mylib.aggregateLossSummary mean stddev skewness kurtosis
          p95 p995=var pctlpts=95 97.5 99;
   performance details threads=2;
run;

title "Distribución de S";
proc sgplot data=mylib.aggregateLossSample;
	histogram aggloss;
run;
title;



