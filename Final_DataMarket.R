library(stringr)
library(dplyr)
library(data.table)
library(readr)
library(gtools)
library(parallel)
library(doParallel)
library(glue)
library(rvest)
library(stringr)
library(tidytext)
library(jiebaR)
library(e1071)
library(ranger)
library(fastNaiveBayes)
library(tibble)


#Encode
SEARCH_ENCODE=function(file_path){
  #prevent some file is empty so guess_encoding will make error caused.
  a=
    tryCatch(readr::guess_encoding(file_path),
             error=function(e) return(matrix(NA,1,1))
    )
  if(is.na(a[1,1])){
    return('unknown')
  }else{
    return(a[1,1] %>% as.character()) 
  }
}

#Prevent type of html file with csv format in my cleaning processing

Discri_HTML_File=function(file_path){
  yes= #24 usual comment in html
    "<html|<style|font-size|<span|body  onload|background-|<script|color|\\.style|<meta|<open|<head|<!DOCTYPE|<title|<body|<kml|<name|<SimpleField|<link|<div|<table|<input|<form|</"
  code=SEARCH_ENCODE(file_path)
  discri_text=readLines(con = file_path,n = 25,
                        encoding = ifelse(code == 'unknown','UTF-8',code))
  ifelse(sum(grepl(discri_text,pattern = yes))>4,TRUE,FALSE) %>% return
}

#Delete worse file so that we can focus on 'better' file in processing data clearning
Discri_worse_file=function(data_path){
  readline_n=10 #readline_number
  code=SEARCH_ENCODE(data_path)
  discri_1=",|\\t| |，" #separate sign
  discri_text=readLines(con = data_path,n =readline_n,
                        encoding =ifelse(code == 'unknown','UTF-8',code))
  discriminant=str_count(string=discri_text,pattern = discri_1) %>% sum
  if(discriminant >5){
    return(F)
  }else{
    return(T)
  }
}



#Determine function to classify file in 
#good,warning,error three categories by fread comment
deter=function(filepath){ #csv file path
  enc=SEARCH_ENCODE(filepath)
  result=tryCatch({
    fread(filepath,
          encoding =ifelse(enc =='UTF-8','UTF-8','unknown'),
          integer64 = 'numeric') 
    return('good')
  },
  warning=function(msg){
    return(msg$message)
  },
  error=function(e) return('error')
  )
  if(result %in% c('good','error')){
    return(result)
  }else{
    while(str_detect(string=result,
                     pattern = 'Previous fread\\(\\) session was not cleaned')){
      result=tryCatch({
        fread(filepath,
              encoding =ifelse(enc =='UTF-8','UTF-8','unknown'),
              integer64 = 'numeric') 
        return('good')
      },
      warning=function(msg){
        return(msg$message)
      },
      error=function(e) return('error')
      )
    }
    if(result %in% c('good','error')){
      return(result)
    }else{
      return('warning')
    }
  }
}

#dealt duplicated name
solve_problem_1=function(data){ #return data
  col_name=
    colnames(data)
  i=1
  while(duplicated(col_name) %>% sum !=0){
    p=duplicated(col_name) %>% which
    col_name[p]=str_replace(string=col_name[p],pattern = '\\.\\d+',"")
    col_name[p]=paste0(col_name[p],'.',i)
    i=i+1
  }
  colnames(data)=col_name
  return(data)
}

#clean- remove column or row contains whole  "" or NA
rm_rowANDcolumn_bad=function(data){
  row_n=nrow(data);col_n=ncol(data)
  if(row_n == 0){ #not meaningful data
    return(data)
  }
  #column
  na_col=sapply(data,is.na) %>% matrix(ncol=col_n) %>% apply(2,sum)
  space_col=sapply(data,function(x) x=="") %>% matrix(ncol=col_n) %>% apply(2,sum,na.rm=T)
  c1=(na_col == row_n) %>% which
  c2=(space_col == row_n) %>% which
  c_total=union(c1,c2)
  #remove condition satisfied column
  keep_c=setdiff(1:col_n,c_total)
  #row
  bad_row=apply(data,1,function(x) x %in% c('',NA)) %>% t %>% 
    apply(1,sum)
  r_total=which(bad_row == col_n)
  keep_r=setdiff(1:row_n,r_total)
  #return data deleted bad row & column
  data %>% select(keep_c) %>% slice(keep_r) %>% return
}

#test encoding correct or not
TEST_ENCODE=function(data){
  n=dim(data)[1]
  if(n>0){ #prevent data has no obs
    guess1=tryCatch(nchar(data[1,],keepNA = F),
                    warning=function(msg) return('W'),
                    error=function(e) return('e')) 
  }else{
    guess1=0
  }
  if(n>4){ #prevent data has no 5 obs
    guess2=tryCatch(nchar(data[5,],keepNA = F),
                    warning=function(msg) return('W'),
                    error=function(e) return('e')) 
  }else{
    guess2=0
  }
  guess3=tryCatch(nchar(colnames(data),keepNA = F),
                  warning=function(msg) return('W'),
                  error=function(e) return('e'))
  if(class(c(guess1,guess2,guess3)) == 'character'){
    return('Maybe wrong encode')
  }else{
    return('OK')
  }
}


#Last discriminant
Discriminant=function(data){
  if(dim(data)[2] == 1){ #only one column
    return('Check,it maybe something wrong.')
  }
  if(dim(data)[1] == 0){#does not have row
    return('Check,it maybe something wrong.')
  }
  return('OK')
}


#Start clean
Auto_clean=function(data_path){
  if(!grepl(x = data_path,pattern = '\\.csv')){
    stop('Error for not csv file')
  }else{
    if(Discri_HTML_File(data_path)){
      return('HTML file')
    }
    if(Discri_worse_file(data_path)){
      return('worse file or small file')
    }
    stat=deter(data_path)
    if(stat %in% c('warning','error')){
      #guess separator of variable
      separators <- c(',' , ';' , ' ' , '\t' , '\\|' , ':')
      guess_sep=function(line){
        separators <- c(',', ';', ' ', '\t', '\\|' , ':')
        n=NULL
        for(sep in separators){
          n=c(n,str_count(string = line,pattern = sep))
        }
        return(which.max(n) %>% separators[.]) #if all is same return ,
      }
      Auto_clean2=function(data_path){
        code=SEARCH_ENCODE(data_path)
        if(code == 'unknown'){
          return('Can not solve for encoding')
        }else code=code
        b=readLines(data_path,encoding = code)
        DE=sapply(X = b,FUN = guess_sep,USE.NAMES = F) #判斷分隔符號
        DE=table(DE) 
        DE_sep=which.max(DE) %>% names(DE)[.]
        DE=
          sapply(b,FUN = function(x){
            str_count(string = x,pattern = DE_sep)
          },USE.NAMES = F)
        dE=table(DE)
        DE_max=which.max(dE) %>% names(dE)[.] %>% as.numeric
        if(max(dE)<((4/5)*length(b))){
          return('Can not solve for separate sign')
        }else{
          b=b[DE == DE_max]
          temp=tempfile()
          writeLines(text = b,con = temp,useBytes = T)
          stat=deter(temp)
          if(stat == 'warning'){
            unlink(temp)
            return('Cannot handle.')
          }else if(stat == 'error'){
            unlink(temp)
            return('Cannot handle.')
          }else{
            code=SEARCH_ENCODE(temp)
            data=fread(temp,encoding=ifelse(code == 'UTF-8','UTF-8','unknown'),
                       integer64 = 'numeric')
            if(TEST_ENCODE(data) == 'Maybe wrong encode'){#try to revise warning by changing encoding
              if(code == 'UTF-8'){
                data=fread(temp,encoding='unknown',integer64 = 'numeric')
              }else{
                data=fread(temp,encoding='UTF-8',integer64 = 'numeric')
              }
            }else{#do nothing
              data=data
            }
            setDF(data)
            #discri_duplicated_variable_name
            if(length(colnames(data)) != length(unique(colnames(data)))){
              data=solve_problem_1(data)
            }
            #discri_first_column is description text or not
            if(dim(data)[2] >2){
              discri=grepl(x=data[1,],pattern ='[\u4E00-\u9FA5]+|[0-9]') %>%
                sum
              while(discri == 1){
                data=data[-1,]
                discri=grepl(x=data[1,],pattern='[\u4E00-\u9FA5]+|[0-9]') %>% 
                  sum
              }
            }else{
              data=data
            }
            #clean- remove column or row contains whole  "" or NA
            data=rm_rowANDcolumn_bad(data)
            if(Discriminant(data) == 'OK'){
              return(data)
            }else{
              return('Check')
            }
          }
        }
      }
    }else{
      code=SEARCH_ENCODE(data_path)
      data=fread(data_path,encoding=ifelse(code == 'UTF-8','UTF-8','unknown'),integer64 = 'numeric')
      if(TEST_ENCODE(data) == 'Maybe wrong encode'){#try to revise warning by changing encoding
        if(code == 'UTF-8'){
          data=fread(data_path,encoding='unknown',integer64 = 'numeric')
        }else{
          data=fread(data_path,encoding='UTF-8',integer64 = 'numeric')
        }
      }else{#do nothing
        data=data
      }
      setDF(data)
      #discri_duplicated_variable_name
      if(length(colnames(data)) != length(unique(colnames(data)))){
        data=solve_problem_1(data)
      }
      
      #discri_first_column is description text or not
      if(dim(data)[2] >2){
        discri=grepl(x=data[1,],pattern ='[\u4E00-\u9FA5]+|[0-9]') %>%
          sum
        while(discri == 1){
          data=data[-1,]
          discri=grepl(x=data[1,],pattern='[\u4E00-\u9FA5]+|[0-9]') %>% 
            sum
        }
      }else{
        data=data
      }
      #clean- remove column or row contains whole  "" or NA
      data=rm_rowANDcolumn_bad(data)
      if(Discriminant(data) == 'OK'){
        return(data)
      }else{
        return('Check')
      }
    } 
  }
}
#
source('C:/Users/1903026/Desktop/test.R',encoding = 'UTF-8')
Pred_fun=function(txt){
  #remove number and English word
  txt=gsub(pattern = '[A-Za-z0-9]',replacement = '',x = txt)
  txt=gsub(pattern='\\(|\\)',replacement = '',x = txt)
  txt=gsub(pattern='\\s+',replacement='',x=txt)
  d=unnest_tokens(enframe(txt),output = word,input = value,
                  token = chinese_token) %>%
    group_by(name) %>% count(word)
  d=cast_dtm(data =d,document = name,term = word,value = n)
  p=which(colnames(d) %in% colnames(D))
  if(length(p) == 0){
    return(rep('公共資訊',length(txt)))
  }else{
    d=d[,p]
    d=as.matrix(d)
    temp_v=dim(d)[2]
    #補上沒有的變數
    n=which(!(colnames(D) %in% colnames(d)))
    if(length(n) != 0){
      d=cbind(d,matrix(0,nrow=dim(d)[1],ncol=length(n)))
      colnames(d)[(temp_v+1):dim(d)[2]]=colnames(D)[n]
    }else d=d
    tt1=data.frame(d,stringsAsFactors = F)
    tt1=tt1[,colnames(D)]
    tt1=convert_appear(tt1)
    tt1=data.frame(tt1,stringsAsFactors = F)
    for(i in 1:dim(tt1)[2]){
      tt1[,i]=factor(tt1[,i],levels=c('No','Yes'))
    }
    rs1=predict(model1,ifelse(tt1 == 'Yes',1,0)) %>% as.character()
    rs2=predict(model2,tt1)
    rs2=rs2$predictions %>% as.character()
    rs3=predict(model3,tt1) %>% as.character()
    rs=data.frame(M1=rs1,M2=rs2,M3=rs3,stringsAsFactors = F)
    #decision rule:以svm為主，如果naivebayes和隨機森林出來的結果一致，以此兩模型結果為主
    if(dim(rs)[1] == 1){
      if(rs[,1] == rs[,2]){
        rs_temp=rs[,1]
      }else{
        rs_temp=rs[,3]
      }
    }else{
      rs_temp=
        apply(rs,1,function(x){
          if(x[1] == x[2]){
            x[1] %>% return
          }else{
            x[3] %>% return
          }
        })
    }
    return(rs_temp)
    # return(rs3)
  }
}

# Final_fun=function(TXT=NULL,file_path=NULL){
#   if(length(TXT) == 0 & length(file_path) == 0){
#     return('Error for no parameter')
#   }else if(length(TXT) == 0 & length(file_path) !=0){
#     return(list(data=Auto_clean(file_path)))
#   }else if(length(TXT) != 0 & length(file_path) ==0){
#     return(list(Tag=Pred_fun(TXT)))
#   }else{
#     if(length(TXT) == length(file_path)){
#       a=Auto_clean(file_path)
#       b=Pred_fun(TXT)
#       return(list(Tag=b,data=a)) 
#     }else{
#       return('Error for not same length of txt and length of file_path')
#     }
#   }
# }
# 
# 



