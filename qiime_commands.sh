#!/bin/bash
#Make sure you run this in your conda environment with the qiime2 environment activated

mkdir -p qiime_artifacts
cd sequence_data/
#This command imports the FASTQ files into a QIIME artifact
#qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' --input-path import_to_qiime --output-path CBW_reads

#Using DADA2 to analyze quality scores of 10 random samples
qiime demux summarize --p-n 10000 --i-data CBW_Willis_reads.qza --o-visualization qual_viz

#Denoising with DADA2. Using quality score visualizations, you can choose trunc-len-f and trunc-len-r (note: sequences < trunc-len in length are discarded!)
qiime dada2 denoise-paired --i-demultiplexed-seqs CBW_Willis_reads.qza --o-table unfiltered_table --o-representative-sequences representative_sequences --p-trunc-len-f 240 --p-trunc-len-r 240 --p-n-threads 4 --o-denoising-stats denoise_stats.qza --verbose

#wget https://data.qiime2.org/2019.1/common/gg-13-8-99-nb-classifier.qza
#If you have a large amount of RAM (32GB or greater), try the larger SILVA database:
wget https://data.qiime2.org/2021.4/common/silva-138-99-nb-classifier.qza

qiime feature-classifier classify-sklearn --i-classifier gg-13-8-99-nb-classifier.qza --i-reads representative_sequences.qza --o-classification taxonomy

#This visualization shows us the sequences/sample spread
qiime feature-table summarize --i-table unfiltered_table.qza --o-visualization table_summary

#Taxa bar plots
qiime taxa barplot --i-table table.qza --i-taxonomy taxonomy.qza --m-metadata-file METADATA.txt --o-visualization taxa-bar-plots

#Steps for generating a phylogenetic tree
qiime alignment mafft --i-sequences representative_sequences.qza --o-alignment aligned_representative_sequences

qiime alignment mask --i-alignment aligned_representative_sequences.qza --o-masked-alignment masked_aligned_representative_sequences

qiime phylogeny fasttree --i-alignment masked_aligned_representative_sequences.qza --o-tree unrooted_tree

qiime phylogeny midpoint-root --i-tree unrooted_tree.qza --o-rooted-tree rooted_tree

rm -r diversity_2000

#Generate alpha/beta diversity measures at 2000 sequences/sample
#Also generates PCoA plots automatically
qiime diversity core-metrics-phylogenetic --i-phylogeny rooted_tree.qza --i-table unfiltered_table.qza --p-sampling-depth 2000 --output-dir diversity_2000 --m-metadata-file METADATA.txt

#Test for between-group differences
qiime diversity alpha-group-significance --i-alpha-diversity diversity_2000/faith_pd_vector.qza --m-metadata-file METADATA.txt --o-visualization diversity_2000/alpha_PD_significance

qiime diversity alpha-group-significance --i-alpha-diversity diversity_2000/shannon_vector.qza --m-metadata-file METADATA.txt --o-visualization diversity_2000/alpha_shannon_significance

#Alpha rarefaction curves show taxon accumulation as a function of sequence depth
qiime diversity alpha-rarefaction --i-table unfiltered_table.qza --p-max-depth 2000 --o-visualization diversity_2000/alpha_rarefaction.qzv --m-metadata-file METADATA.txt --i-phylogeny rooted_tree.qza
