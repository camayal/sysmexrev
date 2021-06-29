; #Info# ======================================================================================================================
; Title .........: Datataxa
; Version .......: U
; AutoIt Version : 3.3.14.2
; Language ......: English
; Description ...: Extract information and classify it from GenBank for a list of species, using Entrez API
; Author ........: Carlos Alonso Maya-Lastra
; Date ..........: March 2016 - May 2020
; =============================================================================================================================


;USER AREA
; =============================================================================================================================

; Switches
$doExtraction = True;<== Switch to True to do the extraction of genbank. False when extraction is finished.
$doMetasearch = False ;<== Switch to True to do the meta search, only when the entire extraction is completed. False when extraction is in progress.

;Input and output files
$oFileSp = "ListaSPPParaBuscarMexico.txt" ;<== File name (file formated Genus+species one species per line)
$fResultFile = "FIRSTTEST.csv" ;<== Define output file name

;Create punctual.searches
Local $aS[6] ; <== Define number searches, this number is independent to the $aE[Number]
$aS[0] = "Phylogenetic studies"
$aS[1] = "Phylogeographic studies"
$aS[2] = "Phylogenomics studies"
$aS[3] = "Barcoding studies"
$aS[4] = "Diversity studies"
$aS[5] = "Biogeography studies"

;Create Regex patterns to search for each punctual.searches, please see regex documentation in: https://www.autoitscript.com/autoit3/docs/functions/StringRegExp.htm
Local $aRegex[6] ; <== Same as punctual.searches AND IN THE SAME ORDER!
$aRegex[0] = "(?i)phylogen|filogen|monop|monof|systemat|relationsh|sistemat|relacio"
$aRegex[1] = "(?i)filogeog|phylogeog"
$aRegex[2] = "(?i)phylogenom|genome-scale|plastid genome|filogenóm"
$aRegex[3] = "(?i)barcod|barra"
$aRegex[4] = "(?i)genetic diversity|diversidad genética|population genetic|genética pobla|genética de pobla"
$aRegex[5] = "(?i)biogeog"


;ADVANCE USER AREA
; =============================================================================================================================


;XML nodes from Genbank results
Local $aE[3] ;<== Define number of element to obtain from the FlatFile and below define which element ("//parentnode/childnode/childnode/...")
$aE[0] = "//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE/SAMPLE/SAMPLE_NAME/SCIENTIFIC_NAME"
$aE[1] = "//EXPERIMENT_PACKAGE_SET//EXPERIMENT/IDENTIFIERS/PRIMARY_ID"
;$aE[2] = "//GBSet/GBSeq/GBSeq_length"
$aE[2] = "//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE/STUDY/DESCRIPTOR/STUDY_TITLE"
;$aE[3] = "//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE/STUDY/DESCRIPTOR/STUDY_TITLE"
;$aE[4] = "//GBSet/GBSeq/GBSeq_create-date"







;Create file and define headings
Local $aT[4] ; <== Define number of titles for each column (Final must be extras)
$aT[0] = "Species after GB analysis"
$aT[1] = "GB Number"
;$aT[2] = "Length"
$aT[2] = "Paper titles" ; <== This number is important in the next definition $arrayofPaperTitles
;$aT[3] = "Paper Journals"
;$aT[4] = "Create date"
$aT[3] = "Searched name"

;Define the array element when the paper titles is saved $aT[__This Number__]
$arrayofPaperTitles = 2

;Define number of accessions  to retrieve from GenBank. Maximum 10000000.
;This number means that if a species has 300.000 accessions (like Manihot esculenta) only first 100000 will be considered
;Remember, Datataxa only save the progress when each species is finished.
$retmax = 1000000

;Define your personal API-key to increase the number of requests per second to Genbank. Put your API-key in between quotations.
;For more information create and NCBI account and generate an API-key here https://www.ncbi.nlm.nih.gov/account/settings/
$api_key = ""



;DO NOT MODIFY BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING
; =============================================================================================================================

#include <MsgBoxConstants.au3>
#include <Array.au3>
#include <File.au3>

;EXTRACTION PART

;Define variables and objects
$oXML = ObjCreate("Microsoft.XMLDOM")
$oHTTP = ObjCreate("Msxml2.XMLHTTP.6.0")

if $api_key = "PUT_HERE_YOUR_KEY" Or $api_key = "" Then
$time = 350
$apiInfo = ""
Else
$time = 110
$apiInfo = "&api_key=" & $api_key
EndIf


if $doExtraction = True then

;Count species in file
$nFileSpLines = _FileCountLines($oFileSp)

;Resume function
if FileExists("continue.txt") then
   $cont = FileRead("continue.txt")
Else
   $cont = 1 ;put 1 to start from first line
   ;Create headers
   For $T in $aT
	  FileWrite($fResultFile, Chr(34) & $T & Chr(34) & ",")
   Next
   FileWrite($fResultFile, @CRLF)
EndIf

;Line by line in the file
For $i = $cont To $nFileSpLines
   ;Show progress
   ;ToolTip($i &" of "& $nFileSpLines, 0,0)

;~    ControlSetText('', '', 'Scintilla2', '')
   ;ControlSend("[CLASS:SciTEWindow]", "", "Scintilla2", "+{F5}")




   ;Clear main variable for final step array to file
   Local $finalRow = ""

   ;Get species from file
   $sSp = FileReadLine($oFileSp,$i)

 $progressMsg = "Processing " & $sSp &" ("& $i &" of "& $nFileSpLines &")"
   ConsoleWrite($progressMsg & @CR)
   TraySetToolTip($progressMsg)

   ;Verify is sp is not empty
   if $sSp <> "" Then

	  ;Search for the name of species in the GB database and correct it if necesary
	  Local $sSpSpace = StringReplace($sSp, "+", " ") ;Replace + by space in the name of sp
	  Local $sErroneousSp = ""
	  ;Local $sXML = HttpPost("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/espell.fcgi?db=taxonomy&term=%22" & $sSp & "%22") ;Access to Espell database to correct

	  $oHTTP.Open("GET", "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/espell.fcgi?db=taxonomy&term=%22" & $sSp & "%22" & $apiInfo, False)
	  $oHTTP.Send()
	  sleep($time) ;Insert delay to respect GenBank Entrez limitation

	  ;ConsoleWrite($oHTTP.ResponseText)

	  $oXML.loadXML($oHTTP.ResponseText)
	  Local $correctedSp = $oXML.SelectSingleNode("//eSpellResult/CorrectedQuery")
	  if StringLen($correctedSp.text) > 0 Then
		 if $sSpSpace <> $correctedSp.text Then
			$sErroneousSp = $sSpSpace
			$sSp = $correctedSp.text
		 EndIf
	  EndIf



	  ;Get XML from Eserch utility of Entrez API
	  ;Local $sXML = HttpPost("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=nucleotide&term=%22" & $sSp & "%22[Organism]&retmax=1000") ;Remember this search can look syns.



	  $oHTTP.Open("POST", "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=sra&term=%22" & $sSp & "%22[Organism]&retmax=" & $retmax & $apiInfo, False)
	  $oHTTP.Send()
	  sleep($time) ;Insert delay to respect GenBank Entrez limitation
;~ ConsoleWrite("check1" & @CR)
	  ;ConsoleWrite($oHTTP.ResponseText)
	  ;Get IdList elements (aka GI number)
	  $oXML.loadXML($oHTTP.ResponseText)
;~ ConsoleWrite("check2" & @CR)
	  ; Verify if the species has some nucleotide registry in GB, else go to the next species
	  If $oXML.SelectSingleNode("//eSearchResult/Count").text > 0 Then

		 ;Get ID numbers for the species
		 $oIDList = $oXML.SelectSingleNode("//eSearchResult/IdList")
		 $aIds = StringReplace($oIDList.text, " ", ",") ;formating changing spaces by commas to put in URL of API

		 ;Create an array with all ID, 0 is the size, 1 is the first element
		 $arrIDs = StringSplit($oIDList.text," ")
		 ;ConsoleWrite($arrIDs[0] & @CRLF)


;Split big array in 400 elements to fit into the URL to send to genbank
for $startSublist = 1 To $arrIDs[0] Step 400


   ;If array is smaller than current endsublist (less than 400 elements), correct it (number of elements can vary depends on lenght of ID, sp. 500 items, fails, so 400 is ok for now)
   $endSublist = $startSublist + 399
   If $arrIDs[0] < $endSublist Then
	   $endSublist = $arrIDs[0]
   EndIf
;~    ConsoleWrite($endSublist & @CR)
;~ ConsoleWrite("check3" & @CR)
   $progressMsg = "Processing accession batch " & Ceiling($endSublist/400) & " of " & Ceiling ($arrIDs[0]/400) & " for " & $sSp & " (" & $arrIDs[0] & " accessions)"
   ConsoleWrite($progressMsg & @CR)
   TraySetToolTip($progressMsg)





   $sublist = _ArrayToString ($arrIDs, ",", $startSublist, $endSublist)
   ;ConsoleWrite($sublist & @CRLF)


;If is the first subset of id, create the final XML
   if $startSublist == 1 Then
	  $oFinalXML=ObjCreate("Microsoft.XMLDOM") ;create xml object
	  $oRoot = $oFinalXML.createElement("EXPERIMENT_PACKAGE_SET") ;create root (exact nomenclature of GeneBank)
	  $oRoot.setAttribute("creator",'Datataxa') ;just a note
	  $oFinalXML.appendChild($oRoot) ;add root node to object
   EndIf

;~ ConsoleWrite("check4" & @CR)


   ;Start searching in GenBank for  ID numbers in batch

   ;Get detailed flatfile from GenBank in XML format for multiple accessions
   ;Local  $sXML = HttpPost("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=" & $aIds & "&retmode=xml")

;SRA
;https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=sra&id=14237486&retmode=xml

   $oHTTP.Open("POST", "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=sra&id=" & $sublist & "&retmode=xml" & $apiInfo, False)
   $oHTTP.Send()
   sleep($time) ;Insert delay to respect GenBank Entrez limitation

;~    ConsoleWrite($oHTTP.ResponseText)

;~ ConsoleWrite("check5" & @CR)

   $oXML.loadXML($oHTTP.ResponseText) ;load xml in the object
;~ 			$oGBSeq = $oXML.SelectNodes("//GBSet/GBSeq") ; select each node (correspond to each accs. number)
   ;copy oXML object to a new object to avoid duplication in XML
   $osubsetXML = $oXML


   ;SRA
   ;"//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE"
   ;"//EXPERIMENT_PACKAGE_SET"

   $oGBSeq = $osubsetXML.SelectNodes("//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE") ; select each node (correspond to each accs. number)
   $oParent = $oFinalXML.SelectSingleNode("//EXPERIMENT_PACKAGE_SET") ; select the parent, where the GBSeq nodes from big XML will be added
   ;iteration for each selected noded in oXML object to add to FinalXML

;~ ConsoleWrite("check6" & @CR)

   For $eachGBSeq In $oGBSeq
	  $oParent.appendChild($eachGBSeq)
   Next
;~ ConsoleWrite("check7" & @CR)
;~ ConsoleWrite($oFinalXML.xml)
Next


;~ ConsoleWrite("check8" & @CR)


			;Make a loop exploring all elements in the array E
			For $nE In $aE
			   Local $UnificationNode = "" ;clean variable where is written each node from each accs.
			   ;Check each element looking for multiples nodes
			   $x = $oFinalXML.SelectNodes($nE) ;select all nodes in the finalXML


			   For $node In $x

;~ 				  ;get last names to add to the title
;~ 				  Local $lastname = ""
;~ 				  if $nE == "//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE/STUDY/DESCRIPTOR/STUDY_TITLE" Then
;~ 					 $ALast = $oFinalXML.SelectNodes("//EXPERIMENT_PACKAGE_SET/EXPERIMENT_PACKAGE/Organization/Contact/Name/Last")
;~ 					 Local $counter_laa = 0
;~ 					 For $laa In $ALast
;~ 						$counter_laa += 1
;~ 						if $counter_laa == 1 Then
;~ 						   ConsoleWrite($laa.text)
;~ 						   $lastname = $laa.text
;~ 						endif
;~ 					 Next
;~ 				  EndIf

				  $UnificationNode &= $node.text & "|" ;add each node info separated by | for each node

			   Next
			   Local $aUniNode = StringSplit($UnificationNode, "|") ;Convert the object into an array splitting the string
			   Local $UnificationNodeUnique = _ArrayUnique($aUniNode) ;Due multiple repetitive data into diferente accs. I filter each node-group (only uniques)
			   $UnificationNodeReport = StringTrimRight(_ArrayToString($UnificationNodeUnique, "|", 2),1) ;Delete the extra_separator at the end
			   $finalRow &= Chr(34) & $UnificationNodeReport & Chr(34) & "," ;add to $finalRow the info

			Next

			;Add XML extracted information to each row
			FileWrite($fResultFile, $finalRow)

			;Add extras to each row (finals columns)
			FileWrite($fResultFile, Chr(34) & $sSpSpace& Chr(34) & @CRLF)

			;sleep(400) ;Insert delay to respect GenBank Entrez limitation

			;Mark line in progress for restart process (script start from this point if stop exe happens)
 			FileDelete("continue.txt")
			FileWrite("continue.txt", $i + 1)



	  EndIf
   EndIf


next

For $beep = 1 To 7
Beep(Random(350, 1000, 1), 200)
next

   ConsoleWrite("Extraction finished" & @CRLF)


Else
   ConsoleWrite("Extraction skipped" & @CRLF)
Endif

;METASEARCH PART

;Avoid overwrite the metasearch results
if FileExists("Metasearch_in_" & $fResultFile ) And $doMetasearch = True then
$doMetasearch = False
ConsoleWrite("The file " & "Metasearch_in_" & $fResultFile & " already exists, to perform a new metasearch delete or move the file" & @CRLF)
EndIf


If $doMetasearch = True Then

;Count species in file
$nFileResultLines = _FileCountLines($fResultFile)

;Indicates the Metasearch file result
Local $fMetaResult = "Metasearch_in_" & $fResultFile

;Create headers of the Metasearch file result
For $T in $aT
	  FileWrite($fMetaResult, Chr(34) & $T & Chr(34) & ",")
Next
For $S in $aS
	  FileWrite($fMetaResult, Chr(34) & $S & Chr(34) & ",")
Next
FileWrite($fMetaResult, @CRLF)


;Extract line by line from the 2nd row (excluding headers)
   For $i = 2 To $nFileResultLines
	  ;clean previous result or declare variable
	  Local $metaseachResultPerLine = ""


   ;Get the line from file
   $sLine = FileReadLine($fResultFile,$i)
   ;Return the field where is located the paper titles
   Local $aField = StringSplit($sLine,Chr(34) & "," & Chr(34), 1)

   ;Perform the metasearch
   For $R in $aRegex
	  $search = StringRegExp($aField[$arrayofPaperTitles+1], $R)
	  If $search = 1 Then
	  $metaseachResultPerLine = $metaseachResultPerLine & Chr(34) & "TRUE" & Chr(34) & ","
	  Else
	  $metaseachResultPerLine = $metaseachResultPerLine & Chr(34) & "FALSE" & Chr(34) & ","
	  Endif

   Next

;Add results to result file (delete the las ,)
FileWrite($fMetaResult, $sLine & "," & StringTrimRight($metaseachResultPerLine,1) & @CRLF)



ConsoleWrite($i-1 & " of " & $nFileResultLines-1 & @CRLF)



   Next


For $beep = 1 To 7
Beep(Random(350, 1000, 1), 200)
next

   ConsoleWrite("Metasearch finished" & @CRLF)


Else
   ConsoleWrite("Metasearch skipped" & @CRLF)
EndIf

if $doExtraction = False And $doMetasearch = False then
      ConsoleWrite("Turn on the desired function using the switches in the script code to run the proper function" & @CRLF)
   EndIf
