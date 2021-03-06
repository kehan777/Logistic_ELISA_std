data{
int N_unkn;           //Total number of unknown values
int N_unkn_grp;       //Total number of unknown samples (should be N_unkn / 4)
int uID[N_unkn];      //Sample number for each unknown value
vector[N_unkn] Unknown; //Optical Density of each unknown
vector[N_unkn] ser_dilutions; //The serial dilutions from the start dilution for each unknown;
  real mu_Std;
  real<lower = 0> sigma_std;
}
transformed data{
  vector[N_unkn] log_ser_dilutions;
  vector[N_unkn] abs_log_ser_dilutions;
  int std_loc;

  log_ser_dilutions <- log(ser_dilutions);
  std_loc <- max(uID);
  for(i in 1:N_unkn)
    abs_log_ser_dilutions[i] <- fabs(log_ser_dilutions[i]);
}
parameters{
  real<lower = 0> sigma;


  real mu_Span;
  real mu_Bottom;
  real<lower = 0> mu_Slope;


  vector[N_unkn] log_x_raw; // log of each unknown's initial concentration
  vector[N_unkn_grp - 1] log_theta;  // log of each unknown's predicted concentration
  real<lower = 0> sigma_x;
  real pred_std_raw;
  cholesky_factor_corr[2] L;
  vector<lower =  0>[2] L_sigma;
  vector[2] alpha;
  vector[2] mu;
}
transformed parameters{
    real<lower = 0> mu_Asym;
  real mu_log_Inflec;

  {
    vector[2] temp;

    temp <- mu + diag_pre_multiply(L_sigma, L) * alpha;

    mu_Asym <- temp[1];
    mu_log_Inflec <- temp[2];
  }
}
model{
  vector[N_unkn] unkn_cOD;
  vector[N_unkn] log_x;
  vector[N_unkn] log_Undil;
  real pred_std;

  sigma ~ normal(0, 1);
  mu_Bottom ~ normal(0.05, 0.01);
  mu_Span ~ normal(3.5, 0.1);
  mu_Slope ~ normal(1, 0.5);

  alpha ~ normal(0, 1);
  L ~ lkj_corr_cholesky(4);
  L_sigma ~ normal(0, 1);
  mu[1] ~ normal(1, 0.5);
  mu[2] ~ normal(0, 1);

  //Multilevel unknown estimation
  log_theta ~ uniform(-10, 15);
  log_x_raw ~ normal(1, 0.5);
  pred_std_raw ~ normal(0, 1);

  pred_std <- mu_Std + pred_std_raw * sigma_std;

  for(i in 1:N_unkn){
    if(uID[i] == std_loc){
      log_Undil[i] <- log(pred_std);
    } else {
      log_Undil[i] <- log_theta[uID[i]];
    }
  }

  log_x <- (log_ser_dilutions + log_Undil) + (sigma_x * abs_log_ser_dilutions) .* log_x_raw;

  for(i in 1:N_unkn){
    unkn_cOD[i] <- mu_Bottom + mu_Span * inv_logit((log_x[i] - mu_log_Inflec) * mu_Slope) ^ mu_Asym;
  }

  Unknown ~ normal(unkn_cOD, sigma);
}
generated quantities{
  vector[N_unkn_grp - 1] theta;
  vector[N_unkn] x;

{
  vector[N_unkn] log_Undil;
  real pred_std;

  pred_std <- mu_Std + pred_std_raw * sigma_std;

  for(i in 1:N_unkn){
    if(uID[i] == std_loc){
      log_Undil[i] <- log(pred_std);
    } else {
      log_Undil[i] <- log_theta[uID[i]];
    }
  }

  x <- exp((log_ser_dilutions + log_Undil) + (sigma_x * abs_log_ser_dilutions) .* log_x_raw);
}
  theta <- exp(log_theta);
}
