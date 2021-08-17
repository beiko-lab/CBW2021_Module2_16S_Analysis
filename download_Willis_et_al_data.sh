#!/bin/bash

#Set the project accession from EBI
ACCESSION=PRJNA506220

#Put everything in a folder
mkdir -p sequence_data
cd sequence_data

#Fetch the project file manifest in TSV format
curl -sLo MANIFEST.txt "https://www.ebi.ac.uk/ena/portal/api/search?query=study_accession=%22PRJNA506220%22&result=read_run&fields=run_accession,sample_accession,fastq_ftp&format=tsv"

#Fetch each of the noted FASTQ files
#You can rerun the script multiple times and it will only redownload the files that aren't there. 
#Useful if wget hangs and you have to ctrl+c and it moves on to the next one. 
#Just run these lines in sequence_data again. 
#The first line clears out all .fastq.gz that haven't had their timestamp set properly, which happens when the download is complete and successful.
find . -name "*.fastq.gz" -mtime -1 -type f -exec rm '{}' \;
awk 'BEGIN{FS="\t";}{if (NR>1) {split($3, f, ";"); system("wget -nc " f[1]); system("wget -nc " f[2]);}}' MANIFEST.txt

#Clear out METADATA.txt if it exists
rm -f METADATA.txt
#Fetch the metadata for each sample
for SAMPLE_ACCESSION in `tail -n +2 MANIFEST.txt | cut -f 2`
do
    #Get the XML report from EBI
    curl -sLo ${SAMPLE_ACCESSION} "https://www.ebi.ac.uk/ena/browser/api/xml/${SAMPLE_ACCESSION}"

    #If there is no metadata file, write the first line
    if [ ! -f "METADATA.txt" ]
    then
        #Scrape the metadata categories from the XML file, save them as the header
        awk 'BEGIN{ORS=""; OFS=""; i=1} {if ($0~/<SAMPLE_ATTRIBUTE>/) { getline; split($0,x,">"); split(x[2], y, "<"); tag[i]=y[1]; i+=1;}} END{print "#SampleID" "\t" "sample_label"; for (j=1; j<=i; j++){print "\t" tag[j];}}' ${SAMPLE_ACCESSION} > METADATA.txt
    fi

    #Scrape the metadata values from the XML file, save them as a new row
    awk 'BEGIN{ORS=""; OFS=""; i=1} {if ($0~/ENA-RUN/) {getline; split($0, x, ">"); split(x[2], y, "<"); run=y[1];} if ($0~/SUBMITTER_ID/) { split($0, x, ">"); split(x[2], y, "<"); samplename=y[1];}; if ($0~/<SAMPLE_ATTRIBUTE>/) { getline; getline; split($0,x,">"); split(x[2], y, "<"); value[i]=y[1]; i+=1;}} END{print "\n"; print run "\t" samplename; for (j=1; j<=i; j++){print "\t" value[j];}}' ${SAMPLE_ACCESSION} >> METADATA.txt
done

#Put the data into a QIIME-importable format
mkdir -p import_to_qiime
cd import_to_qiime

#Name the files as per standard CASAVA pipeline format, which QIIME likes
for accession in `cut -f 1 ../METADATA.txt | tail -n +2 | xargs`; do
   ln -s ../${accession}_1.fastq.gz ${accession}_S0_L001_R1_001.fastq.gz
   ln -s ../${accession}_2.fastq.gz ${accession}_S0_L001_R2_001.fastq.gz
done
#Get a list of the .fastq.gz files, cut out the filename, then make a file called MANIFEST that contains the sample id, filename, and whether the read is forward or reverse
ls -l *.fastq.gz | cut -d " " -f 9 | awk 'BEGIN{ORS=""; print "sample-id,filename,direction\n";} {if ($0~/R1/) {dir="forward"} else {dir="reverse"}; split($0, y, "_"); print y[1] "," $0 "," dir "\n";}' > MANIFEST
#Make the metadata.yml that indicates the phred offset of these particular fastq files (generally 33 for everything modern)
echo "{'phred-offset': 33}" > metadata.yml

