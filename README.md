# Taiwan_opendata_processing

![](https://i.imgur.com/0jYCmpz.png)

## 程式使用方式說明

!!!**所有檔案位置需要確實修改**

### Formal_crawl_data 

從資料市集上下載政府資料的函數，需要創一個資料夾放置下載的資料，與資料夾裡面須包含dealt.csv紀錄下載過的資料集代號。

下載Formal_crawl_data.R

**parameter:**
organ='政府開放資料彙整平台' #想找的組織
download_num=100#一次下載的數量
dealt_path='D:/nchc/dealt.csv'#處理過資料集紀錄的位置
save_dir_path='D:/nchc/'#下載後，希望儲存的資料夾位置
update_num=1000 #要求多少筆的修改過的資料集從新到舊

### Auto_clean

自動清理函數，輸入需要清理的csv檔案位置，需下載Final_Data_Market.R

**parameter:**
data_path #檔案位置

### Pred_fun
預測標籤函數，輸入想預測的文字。

注意所有檔案位置皆須更改，且須下載

add_word.txt,

model.RData,

Final_Data_Market.R,

test.R,

chinese_stopword.txt,

transform 資料夾

**parameter:**
txt #文字

**可直接把DataMarketFinal資料夾放在R library裡面，就可直接用相關函數**

## 前情提要
  台灣政府開放資料平台擁有龐大的資料，可以被各領域應用。但很多資料品質不佳，有一些小問題，造成使用上不是這麼方便。像是編碼格式不一、重複變數名稱、資料第一行第二行包含無意義資訊，一整行或列全部NA等，雖然人工來說，不難處理，但每次利用時，都有類似的問題，造成使用者不便或觀感不佳，因此建立自動清理程式，完善大部分資料的小問題。  
  此外，政府開放資料平台上，很多資料集標籤有誤，因類別並無仔細定義清楚，且未仔細審核，導致後來上傳資料者，為了方便皆填寫公共資訊，導致此項資訊幫助不大，因此透過爬蟲獲取資料集標籤，並重組資料，提升資料品質，最後建立分類模型，以期能改善大部分資料皆被分成公共資訊，以及部分資料貼錯標籤等現象，達到標籤資訊有實質意義的目標。


## 下載政府開放資料(Formal_crawl_data)
  從國網中心開放資料集平台(scidm)政府開放資料組織下，下載全部資料，並找出所有csv檔(一般民眾常用檔案格式，最類似xlsx)，如下圖:
  
 ![](https://i.imgur.com/AEy2ISq.png)
 
 因為scidm為ckan架構的網站，有內建的API，會較容易處理。
 
 程式碼邏輯:
 設定網址:ckanr_setup(url='https://scidm.nchc.org.tw/') =>
 
 找出政府開放資料的id:organization_list()  =>
 
 讀取處理過的資料:fread(dealt_path) =>
 
 讀取所有的資料集編號:package_list(limit=10^5)  =>
 
 讀取最新更新檔案:changes(limit=update_num) =>
  
 如果最新檔案id有出現在已處過檔案，判別最後修改日期是否一致。
 是代表不用更新，否代表要更新。如果有不在處理過的資料集，需增加到下載清單裡。
 扣掉所有已處理且不需更新的資料集編號，並找出前面數來download_num個數，即為此次需要下載的資料集編號 =>
 
 讀取資料集資訊:package_show(id) =>
 
 下載與紀錄:curl_download(url,save_path);writeLines(Description_content) =>
 
 結束
 ### 資料清理(Final_Market中的Auto_clean)
  使用R語言data.table中的fread指令讀取檔案，以讀取過程，R產生的反應，作為good,warning,error判別依據，讀取檔案的編碼採用readr裡guess_encoding函數計算出機率最高的編碼作為編碼依據，如果沒有任何編碼超過20%，會歸類成無法處理。
  
![](https://i.imgur.com/YrgxHUP.png)

自動處理函數功能包括:

1.偵測是否為HTML語法檔案(24個網路語法常用程式碼，讀取前30行，超過4行包含，即為HTML語法檔案)
EX:
![](https://i.imgur.com/XEh4e6o.png)

註:24個判別碼
<style，font-size，<span，body  onload，background-
<script，color，<open，<head，<!DOCTYPE
<meta，<title，<body，<name，<kml
<SimpleField，<html，<link，.style，<div
<table，<input，<form，</

2.排除亂碼檔(透過讀取前10行，分隔符號+中文逗號數小於5個)

註:小檔案會被排除


3.處理重複變數名稱
EX:
X1,X2,X3,X3 => X1,X2,X3,X3.1

4.刪除資料描述文字(一行只有一個變數有值)
EX:
![](https://i.imgur.com/LYt2JmU.png)

5.刪除整行或整列NA值

6.當無法完全讀取時，會透過刪除部分資料，嘗試恢復處理程序

7.做最後一次的Re-check，測試編碼是否合理，以及資料的觀測值至少有一筆和超過一個變數

8.回傳統一編碼(Big5)，和統一分隔符號(,)

Ouput:

*清理過的資料

*HTML file

*bad file or small file

*Check

## 資料貼標(Final_Market中的Pred_fun，需先讀取Temp檔獲得模型)

### 資料
1.針對政府開放資料，最後下載了16577筆的Title(資料集名稱)+datameta(資料集描述)，其中有681筆資料集名稱重複，透過隨機選取刪除重複標題，剩餘15896筆。

2.各國政府開放資料，採用分類相似，採用政府開放資料平台上的原始分類，透過額外的爬蟲方式，搜尋資料集的類別，其中有942筆資料集已刪除，無法判別，剩餘14954筆。

3.有2筆Title，詞為英文和停止詞組成，刪除，剩餘14952筆
(嘉義縣政府itaiwan、Financial industry consolidation M&A Deals since September 2004)

4.有23筆Title，刪除停止詞後，剩餘單字皆為長度1的單字，剩餘14929筆

### 資料處理

使用R語言套件中的jiebaR，對文字做斷詞。

**新增各式停止詞**: :no_entry_sign: 
常見用字:一樣,一般,一轉眼,萬一,上,上下,下,不,不僅,不但,不光,不單,不只,不外乎,......

數字:0,1,2,3,4,......

英文:a-zA-Z 

標點符號:，,、,?,。,$,......

台灣地名:花蓮,台中,臺中,宜蘭,彰化,萬里,金山,板橋,汐止,深坑,石碇,瑞芳,平溪,......

時間(副詞):年,月,日,時,分,秒,最近,曾經,過去,現在,未來,......

常見常用但無幫助的字:資料表,數據,資料,政府,本署,報表,......

無意義的字:別分,天內,數按,......

**新增各式字彙**使斷詞更為精準:

新增[**台灣專屬詞庫**](https://github.com/APCLab/jieba-tw/blob/master/jieba/dict.txt?fbclid=IwAR2BAQdVGKb_Fg7TBwn1HKiZmGN9JeaXEzEPQydAmr_Cv0WCcCTmM6thz1g)，約24萬筆單字。

新增[**自建辭彙**](https://github.com/jaesm14774/Taiwan_opendata_processing/blob/master/New%20word)，使斷詞更為精確。

新增部分[搜狗詞庫](https://pinyin.sogou.com/dict/)

(各類別文字雲觀察，可參閱附錄)

### 重組資料
因資料類別不均勻，與部分類別標錯，導致分類困難，採取重組資料，讓資料品質提升。

將**出生及收養**+**婚姻**+**生命禮儀**定義為**生命禮儀**，**老人安養**和**退休**合併為**退休安養**，類別從18項變成15項 。人工盡可能找尋每一個類別的關鍵字，找出不超過400筆的代表性數據。

(找尋的關鍵字可參閱附錄)

<font color='red'>**修正**</font>
開創事業包含一些標題分類錯誤，做修正後，投資理財多增加了19筆數據，超過400筆。

新資料:

3274筆，共15個類別。

![](https://i.imgur.com/DDOWnKD.png)


預先刪除數字與英文後，相同的Title，避免讓模型過度配適，刪除202筆，
剩餘3072筆。

### 建模過程

切割資料集，80%為訓練集，剩餘20%為測試集。

訓練集:2444筆
測試集:628筆

將訓練集做結巴斷詞，共6287個單字變數


運用**全變數**+naivebayes <font color='red'>(不展現confusion matrix，15*15過於凌亂)</font>


![](https://i.imgur.com/9zMA15E.png)

Train accuracy:98.81%
Test accuracy:86.58%

運用**全變數**+randomForest <font color='red'>(不展現confusion matrix，15*15過於凌亂)</font>

![](https://i.imgur.com/o6tCitP.png)

Train accuracy:96.64%
Test accuracy:87.06%

運用**全變數**svm (linear kernel) <font color='red'>(不展現confusion matrix，15*15過於凌亂)</font>

![](https://i.imgur.com/4c1Vk9p.png)

Train accuracy:99.71%
Test accuracy:90.1%

NB

![](https://i.imgur.com/sthG1L7.png)

RF

![](https://i.imgur.com/bSt3IJc.png)

SVM

![](https://i.imgur.com/rlnu870.png)


### 模型選擇

最終模型選擇:

透過各種統計指標(Recall,Precision,Accuracy,...)SVM表現普遍較佳，因此選SVM為主要預測模型。然而SVM在'生命禮儀'這項類別中，平均表現不是這麼好，因此當其他兩個模型預測一致時，採用其他兩模型預測結果。(共292筆不一樣，目測兩模型一致時，貼的標籤較吻合)

### 結論
目前模型以人判別為基準，準確度約為80%左右，需要更多少數類別的資料，除了可以讓各類別個數均衡以外，也能增加各類別的單字，提高準確度。Bag of word模型
很吃資料的單詞數，如果沒出現過，就無法判別，因此如果有更大量的精準資料，就能進一步提升模型。

## 附錄

### 觀察全部資料各類文字雲

<font color="blue"> **生活保健** </font> 

![](https://i.imgur.com/9svWroT.png)



<font color="blue"> **出生及收養** </font> 

![](https://i.imgur.com/f8hN5HB.png)


<font color="blue"> **求學及進修** </font> 

![](https://i.imgur.com/Jt74FLe.png)



<font color="blue"> **服兵役** </font> 

![](https://i.imgur.com/0BNiIwV.png)



<font color="blue"> **求職及就業** </font> 

![](https://i.imgur.com/txHr7Ve.png)



<font color="blue"> **開創事業** </font> 

![](https://i.imgur.com/zZtvgnm.png)


<font color="blue"> **婚姻** </font> 

![](https://i.imgur.com/AbIMzIy.png)



<font color="blue"> **投資理財** </font> 

![](https://i.imgur.com/Qwv40g7.png)



<font color="blue"> **休閒旅遊** </font> 

![](https://i.imgur.com/jBuaMtG.png)



<font color="blue"> **交通及通訊** </font> 

![](https://i.imgur.com/VfelBaA.png)



<font color="blue"> **就醫** </font> 

![](https://i.imgur.com/WW76EiU.png)




<font color="blue"> **購屋及遷徙** </font> 

![](https://i.imgur.com/tIZAy9N.png)



<font color="blue"> **選舉及投票** </font> 

![](https://i.imgur.com/RgcFml8.png)




<font color="blue"> **生活安全及品質** </font> 

![](https://i.imgur.com/DMZkV2y.png)




<font color="blue"> **退休** </font> 

![](https://i.imgur.com/6HAsAzA.png)




<font color="blue"> **老年安養** </font> 

![](https://i.imgur.com/nuPURBR.png)




<font color="blue"> **生命禮儀** </font> 

![](https://i.imgur.com/074OWYG.png)



<font color="blue"> **公共資訊** </font> 

![](https://i.imgur.com/NYlbvcj.png)


### 關鍵字

#### 生育保健(124)

key:
健康|吸菸|二手菸|追蹤|轉介|保健|癌|營養|高血壓|
糖尿病|心血管|衛生|接種|兒童發展|哺集乳室


#### 生命禮儀(46)

key:
出生|新生兒|收養|生前|殯葬|遺囑|生母|退休|公墓|
火化場|火葬|水葬|土葬|骨灰|靈骨塔|火化|墓地|墳墓|
法事|私生兒|私生子|結婚|婚姻|年金|教養機構|懷孕|
產檢|孕婦|戶政事務所|死亡|離婚|嬰兒|收容機構|納骨塔|
忠靈祠|托嬰|喪葬|喪事|托育|保母|配偶|托嬰|殯儀館|育兒津貼|樹葬


#### 求學及進修(340)

key:
大學|大專|技專|學校|中學|小學|國小|國中|高中|五專|四技|學習|
求學|教育|畢業生|進修|第二外語|學術|補習班|研究|科系|學院|教育部|
學年度|專題|培養|圖書|館藏|知識|文學|檢定|博物館|學生|實習生|能力測驗|
技能|考生|二技|二專|幼兒園


#### 服兵役(90)

key:
徵兵|家屬|替代役|常備兵|兵役|抽籤|體檢|檢查|體位



#### 求職及就業(243)

key:
薪資|勞保|受雇|職業病|產業|給付|安全衛生|訓練|退休金|行業別|年金|
退輔會|職訓|人才|徵才|職業訓練|就業|雇主|開業|職缺|工會|工資|失業|職員|員工


#### 開創事業(60)

key:
公司|行業別|投資|研發|創業|清冊|核准|企業|貸款


#### 投資理財(419)

key:
產險|風險|持卡人|票券|授信|成交|市場|保險|上市|上櫃|
有限公司|基金|信用|利率|股票|回饋|反傾銷稅|金融|股份|人壽|控股|
保費|保單|期貨|債券|損益|公債

#### 休閒旅遊(184)

key:
休閒|旅遊|文化|農場|展覽|舞蹈|景點|觀光|電影|音樂|親子活動|演唱會|
藝術|表演|綜藝|講座|美食|旅館|民宿|歌唱|繪畫|戲劇|徵選|藝文|旅客|遊客|
餐廳|運動|手工藝|遊憩|古道|特展|生態園區|導遊|健走|文物|古蹟


#### 交通及通訊(395)

key:
寬頻|行動|計程車|道路|路段|捷運|郵政|停車場|公路|鐵道|上網|
電信|機車|車站|機場|國道|交通事故|酒駕|肇事逃逸|光纖|火車|高鐵|通信|加油站|傳真


#### 就醫(289)

key:
疾病|流感|確診|感染|病例|醫療|年齡層|登革熱|篩檢|診所|腸病毒|
結核病|疫苗|接種|接踵|肝炎|急性|篩檢|症候群|住院|急診|就醫|就診|
治療|門診|病床|診斷|醫院



#### 購屋及遷徙(193)

key:
地價|建物|棟數|地段|地政事務所|不動產|租賃|房價|實價|房地產|
預售屋|法拍屋|土地|租屋|地價|現值|重劃


#### 選舉及投票(16)

key:
選舉|開票|政黨|候選人|總統|投票


#### 生活安全及品質(400)

key:
環保|空汙|品質|食品|安全|天然氣|瓦斯|自來水|廢棄物|
廢管處|有害|廢棄物|廢水|污水|地震|天氣|雨量|
氣象|懸浮粒子|懸浮微粒|汙染|閃電|颱風|梅雨|警報|土石流|
地層下陷|水質|紫外線|落雷|掩埋場|檢驗|稽查|焚化|
暴潮|海嘯|溫室氣體|植栽|節能減碳|家庭托顧|居家照護|
暴露|容許標準|違規|犯罪|被害|勒戒|收容|監獄|
公共危險|毒品|恐嚇|搶奪|殺人|性侵|案件|噪音|家庭暴力|
家暴|防火|消防|竊盜|肇事|輻射|健康|禁菸|無菸|避難|
髒污|火災|溺水|環境|違反|監測|地下水|回收|
核能|公廁|清潔隊|酸雨|食安|有機

#### 退休安養(75)

key:
老人|年金|老年|退休|福利|機構|安養|復健|共餐|托老|銀髮|護理|
長者|長青|長期照顧|榮民


#### 公共資訊(400)
扣除標題有出現上述的所有關鍵字後，剩餘的標題中，隨機抽取400筆

