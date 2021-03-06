library(MASS)
library("parallel")
library("doParallel")
args = commandArgs(trailingOnly=TRUE)
i=as.numeric(args[1])

BB=100
KK=20
MM=50
ncore=10

setwd("/work/unmcresit/zhengc68/Lei")
result5<-read.csv("data5_res.csv")
names(result5)[10:13]<-c("h01","h02","h03","h04")
setwd("/work/unmcresit/zhengc68/Lei/data5")
truepar<-c(0.1,0.1,0.1,0.1,1,0,1,0.2,1,0.5,-0.5,1,1)
cr<-matrix(data=NA,nrow=200,ncol=length(truepar))

qq<-c(0,2,4,6,8)
nr<-200
tlist=c(2,4,6,8)


med5<-function(qq,par,K,M,t,nr){
    bh=c(par[1:4],0)
    alpha1=par[5]
    eta=par[10]
    beta=par[6:8]
    Sigma_a=matrix(data=c(par[12]),nrow=1,ncol=1)
    vare=par[13]
    gamma=par[9]
    delta=par[11]
    NDE<-NIE<-rep(NA,nr)
    for (xi in 1:nr){
        lam<-stepfun(qq[2:(length(qq)-1)],as.numeric(bh[-length(bh)]))
        ###generate potential mediator
        t_vec=(1:K)*(t/K)
        xt=t_vec%o%c(1)
        mu1<-cbind(1,1,xt)%*%beta
        mu0<-cbind(1,0,xt)%*%beta
        Sigma<-diag(rep(vare,K))
        e_vec0<-mvrnorm(M,mu0,Sigma)
        e_vec1<-mvrnorm(M,mu1,Sigma)
        
        samp_a=mvrnorm(M,c(0),Sigma_a)
        a<-samp_a
        m_vec1=e_vec1+a%*%rep(1,K)
        m_vec0=e_vec0+a%*%rep(1,K)
        #        tdif<-t_vec-c(0,t_vec[-length(t_vec)])
        ccum0<-ccum1<-rep(0,M)
        m_a=c(samp_a%*%delta)%o%rep(1,K)
        for (i in 1:M){
            ee0<-stepfun(t_vec,c(exp(eta*m_vec0+m_a*m_vec0)[i,],0))
            ee1<-stepfun(t_vec,c(exp(eta*m_vec1+m_a*m_vec1)[i,],0))
            myf0<-function(u){lam(u)*ee0(u)}
            myf1<-function(u){lam(u)*ee1(u)}
            ccum0[i]<-integrate(myf0,0,t,subdivisions=2000)$value
            ccum1[i]<-integrate(myf1,0,t,subdivisions=2000)$value
        }
        surv_a=samp_a%*%gamma
        S00<-exp(-diag(ccum0)%*%exp(c(alpha1*0)+surv_a))
        S01<-exp(-diag(ccum1)%*%exp(c(alpha1*0)+surv_a))
        S10<-exp(-diag(ccum0)%*%exp(c(alpha1*1)+surv_a))
        S11<-exp(-diag(ccum1)%*%exp(c(alpha1*1)+surv_a))
        NDE[xi]<-mean(S10-S00,na.rm=TRUE)
        NIE[xi]<-mean(S11-S10,na.rm=TRUE)
    }
    mNDE<-mean(NDE)
    mNIE<-mean(NIE)
    return(c(mNDE,mNIE))
}

tmp<-read.table(paste("cov",as.character(i),".txt",sep=""))
tmp_name<-tmp[,1]
tmp<-as.matrix(tmp[,-1])
tmp_se<-sqrt(diag(tmp))
cr[i,]=abs((result5[i,tmp_name]-truepar)/tmp_se)<1.96
tmpdata<-read.csv(paste(as.character(i),".csv",sep=""))
tmpdata<-tmpdata[which(tmpdata$month==0),]
par<-result5[i,tmp_name]


registerDoParallel(cores=ncore)

allres=foreach (t=tlist,.combine=cbind)%dopar%{
	est=med5(qq,as.numeric(par),K=KK,M=MM,t,nr)
        est_boot=foreach (j=1:BB,.combine=rbind) %dopar%{
            	set.seed(1111+j)
            	bootpar=mvrnorm(1,mu=as.numeric(par),Sigma=tmp)
	    	tmpres=rep(NA,length(est))
        	try(tmpres<-med5(qq,bootpar,K=KK,M=MM,t,nr))
		tmpres
        }
	rbind(est,est_boot)
}
setwd("/work/unmcresit/zhengc68/Lei")
write.csv(allres,paste("boot_res5_i=",as.character(i),".csv",sep=""),row.names=FALSE)


