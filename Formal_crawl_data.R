library(dplyr)
library(stringr)
library(ckanr)
library(foreach)
library(doParallel)
library(data.table)
library(curl)
library(rvest)
library(mgsub)
#parameter
organ='政府開放資料彙整平台' #想找的組織
download_num=100#一次下載的數量
dealt_path='D:/n/dealt.csv'#處理過資料集紀錄的位置
save_dir_path='D:/n/'#下載後，希望儲存的資料夾位置
update_num=1000 #要求多少筆的修改過的資料集從新到舊
#處理用package_show的metadata_modified的日期，達到可以比較的格式
#ex:2018-08-11 
form1=function(date){
  tt=str_split(date,pattern = '[ -]',simplify = T)
  tt=apply(tt,1,as.numeric) %>% t
  return(tt)
}
#預期輸出 (2018,8,11)

#Compare two date is same day or not
#date1=update_date;date2=record dealt package of date
update_ornot=function(date1,date2){
  diff_date=date1-date2
  ifelse(diff_date[1]!=0 | diff_date[2]!=0 | diff_date[3]!=0,T,F)
}


#main function
Do_crawl=function(organ,dealt_path,save_dir_path,download_num,
                  update_num){
  c1=makeCluster(4)
  registerDoParallel(c1)
  ckanr_setup(url='https://scidm.nchc.org.tw/',
              key = '')
  #政府開放資料彙整平台
  #find id code with organization we want
  organ_name=organization_list()
  Org_name=data.frame(org=rep(0,length(organ_name)),
                      id=rep(0,length(organ_name)))
  Org_name=foreach(i=1:length(organ_name),.combine='rbind') %dopar%{
    p=organ_name[[i]]
    c(p$display_name,p$id)
  }
  rownames(Org_name)=1:dim(Org_name)[1]
  Org_name=as.data.frame(Org_name)
  Target=Org_name[which(Org_name[,1] == organ),]
  #讀取已處理的紀錄，並判斷是否有需要更新，取決update_ornot
  dealt_package=fread(dealt_path)
  setDF(dealt_package)
  if(dim(dealt_package)[1] ==0){
    x=package_list(limit=10^5,as='table')
    update_id=NULL #no package need to be updated.
  }else{
     a=ckanr::changes(limit=update_num)
     a[[25]]$data$package$id
     
     dat=foreach(i=1:length(a),
                 .combine ='rbind',
                 .export = 'a') %dopar%{
        #防止package已經被刪除，產生的error
         if(a[[i]]$data$package$state == 'deleted'){
            data.frame(package=a[[i]]$data$package$id,
                       condition=0,
                       last_modified=a[[i]]$data$package$metadata_modified,
                       stringsAsFactors = F)
          }else{
            data.frame(package=a[[i]]$data$package$id,
                     condition=ifelse(a[[i]]$data$package$owner_org == Target[1,2],1,0),
                     last_modified=a[[i]]$data$package$metadata_modified,
                     stringsAsFactors = F)
          }
     }
     #remove  duplicated id of package is revised
     dat=dat[!duplicated(dat[,1]),]
     #make date in compared form
     dat[,3]=dat[,3] %>% 
       str_match('[\\w-]+T') %>%
       str_replace('T','')
     dat=dat[dat[,2] == 1,] #no need other organizations we don't need
     if(dim(dat)[1] == 0){ 
       print(paste0('no ',organ,' of package need to update.'))
       update_id=NULL #no package need to be updated.
     }else{
       if(sum(dealt_package[,1] %in% dat[,1]) == 0){
            print('no downloaded package need to update')
            update_id=NULL #no package need to be updated.
       }else{
         p=(dealt_package[,1] %in% dat[,1]) %>% which
         dealt=dealt_package[p,] %>% arrange(package)
         dat=dat %>% arrange(package)
        result=foreach(i=1:length(p),.export=c('update_ornot','dat','dealt'),
                 .combine='c') %dopar%{
                   a=dat[i,3] %>% form1
                   b=dealt[i,3] %>% form1
                   update_ornot(a,b)
                 }
         dat[result==T,1] %>% paste0('ID:',.,'will be updated.')
         update_id=dat[result ==T,1]
       }
     }
     if(length(update_id) ==0){
       x=package_list(limit=10^5,as='table')
       p=which(x %in% dealt_package[,1])
       if(length(p)>0){
         x=x[-p]
       }else x=x
     }else{
       p=which(dealt_package[,1] %in% update_id)
       x=package_list(limit=10^5,as='table')
       x=x[-which(x %in% dealt_package[-p,1])]
     }
  }
  
  #預防沒有這麼多檔案可以下載的error
  if(length(x) < download_num){
    print('Not so many packages you can download')
    warning(paste0('Not so many packages you can download only remaining',
                   length(x),' packages.'))
    download_num=length(x)
  }
  download_num=download_num+length(update_id)
  
  #find owner of organization of those n packages
  Packages=
    foreach(i=1:download_num,.export = 'x',.packages = 'ckanr') %dopar%{
      ckanr_setup(url='https://scidm.nchc.org.tw/',
                  key='')
      package_show(x[i])
    }
  #Record last modified date of package & some text modified
  package_last_mod_date=sapply(Packages,with,metadata_modified,
                               simplify = T)
  package_last_mod_date=package_last_mod_date %>%
    str_split(pattern = 'T',simplify=T) %>% {.[,1]}
  #find the data whose organization is asked.
  owner_org=sapply(Packages,with,owner_org,simplify = T)
  result=owner_org == Target[1,2]
  p=which(result)
  
  #stop function if no package whose organization we asked
  if(length(p) == 0){
    fwrite(x = data.frame(x=x[1:download_num],y=ifelse(result,1,0),
                          z=package_last_mod_date),
           file=dealt_path,append = T)
    stopCluster(c1)
    return('There is no package whose organization is satisified ')
  }else{
    #find the data whose organization is asked.
    Total_data=Packages[p]
    #record dealt packages,and y=1 express organization we want, y= 0 else
    fwrite(x = data.frame(package=x[1:download_num],
                          condition=ifelse(result,1,0),
                          last_modified=package_last_mod_date),
           file=dealt_path,append = T)
    #collect all resources of data in each package,and download it
    z=foreach(i=1:length(Total_data),
              .packages=c('ckanr','doParallel','foreach'),
              .export=c('Total_data','save_dir_path')) %dopar%{
                ckanr_setup(url='https://scidm.nchc.org.tw/',
                            key = '')
                path=paste(save_dir_path,Total_data[[i]]$id,
                           sep='')
                if(!dir.exists(path)){
                  dir.create(path) 
                }
                p=which(sapply(Total_data[[i]]$extras,with,key) == 'fieldDescription')
                if(length(p) >0){
                  x=c(paste0('id:',Total_data[[i]]$id),"",
                      paste0('title:',Total_data[[i]]$title),"",
                      paste0('datameta:',Total_data[[i]]$notes),"",
                      paste0('maintainer:',Total_data[[i]]$maintainer),"",
                      paste0('maintainer_email:',Total_data[[i]]$maintainer_email),"",
                      paste0('author:',Total_data[[i]]$author),"",
                      paste0('author_email:',Total_data[[i]]$author_email),"",
                      paste0('fieldDescription:',
                             Total_data[[i]]$extras[[p]] %>% with(value)),"") 
                }else{
                  x=c(paste0('id:',Total_data[[i]]$id),"",
                      paste0('title:',Total_data[[i]]$title),"",
                      paste0('datameta:',Total_data[[i]]$notes),"",
                      paste0('maintainer:',Total_data[[i]]$maintainer),"",
                      paste0('maintainer_email:',Total_data[[i]]$maintainer_email),"",
                      paste0('author:',Total_data[[i]]$author),"",
                      paste0('author_email:',Total_data[[i]]$author_email),"",
                      paste0('fieldDescription:',
                             ''),"") 
                }
                temp=Total_data[[i]]$resources
                #預防沒有資料來源，只有文字敘述發生的error
                if(length(temp) == 0){
                  y='no resources'
                }else{
                  y=
                    foreach(j=1:length(temp),
                            .packages = c('ckanr','curl'),
                            .export=c('temp','path'),
                            .combine='c') %dopar%{
                              ckanr_setup(url='https://scidm.nchc.org.tw/',
                                          key = 'ef4818c0-9d26-4f47-b18e-f99da4d5990f')
                              #預防沒權限進入網址，發生的error
                              deter=tryCatch(
                                curl_download(url=temp[[j]]$url,
                                              destfile=paste(path,'/',
                                                             j,
                                                             '.',
                                                             temp[[j]]$format %>% 
                                                               tolower(),
                                                             sep='')),
                                error=function(e) -1)
                              if(deter == (-1)){
                                paste(j,':',temp[[j]]$name  %>% gsub(pattern ='[\r\n]',replacement = ''),
                                      ' id: ',temp[[j]]$id,
                                      ' can not access to the url',
                                      sep='')
                              }else{
                                paste(j,':',temp[[j]]$name %>% gsub(pattern ='[\r\n]',replacement = ''),
                                      ' id: ',temp[[j]]$id,
                                      sep='')
                              }
                              #
                            }
                }
                writeLines(text=c(x,y),
                           con=paste(path,'/description.txt',sep=''),
                           useBytes = T)
              }
    stopCluster(c1)
    print('Done')
    return('Done')
  }
}

#Run
system.time(
  Do_crawl(organ,
           dealt_path,
           save_dir_path,
           download_num,
           update_num)
)
#last step
#處理dealt.csv重複內容的函數
#更新package時，如果有更新，會重複寫入dealt.csv，
#因此需要把舊的紀錄刪除，讓程式不會重複跑相同紀錄
#ex:00001 1 2011-12-2 12 & 00001 1 2011-12-31 5
#keep 00001 1 2011-12-31 5 and delete 00001 1 2011-12-2 12
remove_duplicate_record=function(dealt_path){
  a=read.csv(dealt_path)
  a=a[!duplicated(a[,1],fromLast = T),]
  return(a)
}
write.csv(remove_duplicate_record(dealt_path),
          file = dealt_path,row.names = F)


