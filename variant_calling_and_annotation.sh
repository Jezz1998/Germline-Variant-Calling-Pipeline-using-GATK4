# GATK Germline Variant Calling Pipeline Shell Script

#!/bin/bash

set -e

echo "==========================================="
echo "GATK Germline Variant Calling Pipeline"
echo "==========================================="

# Create Project Structure
mkdir -p ngs_variant_project/{reads,aligned_reads,results,data,support_files/hg38}

cd ngs_variant_project/

############################################
# STEP 1: Download FASTQ Reads
############################################

echo "STEP 1: Downloading FASTQ Reads"

wget -P reads ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_1.filt.fastq.gz
wget -P reads ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_2.filt.fastq.gz

############################################
# STEP 2: Download Reference Genome
############################################

echo "STEP 2: Downloading Reference Genome"

wget -P support_files/hg38 https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz

gunzip -f support_files/hg38/hg38.fa.gz

############################################
# STEP 3: Reference Indexing
############################################

echo "STEP 3: Reference Indexing"

samtools faidx support_files/hg38/hg38.fa

bwa index support_files/hg38/hg38.fa

gatk CreateSequenceDictionary \
-R support_files/hg38/hg38.fa \
-O support_files/hg38/hg38.dict

############################################
# STEP 4: Quality Control
############################################

echo "STEP 4: Running FastQC"

fastqc reads/SRR062634_1.filt.fastq.gz -o reads/
fastqc reads/SRR062634_2.filt.fastq.gz -o reads/

############################################
# STEP 5: Alignment using BWA-MEM
############################################

echo "STEP 5: Aligning Reads"

bwa mem -t 8 \
-R "@RG\tID:SRR062634\tSM:HG00096\tPL:ILLUMINA\tLB:lib1\tPU:unit1" \
support_files/hg38/hg38.fa \
reads/SRR062634_1.filt.fastq.gz \
reads/SRR062634_2.filt.fastq.gz \
> aligned_reads/SRR062634.paired.sam

############################################
# STEP 6: Mark Duplicates
############################################

echo "STEP 6: Marking Duplicates"

gatk MarkDuplicatesSpark \
-I aligned_reads/SRR062634.paired.sam \
-O aligned_reads/SRR062634_dedup.bam \
-M aligned_reads/SRR062634_dup_metrics.txt

############################################
# STEP 7: Download Known Sites for BQSR
############################################

echo "STEP 7: Downloading Known Variant Sites"

wget ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/dbsnp_138.hg38.vcf.gz
wget ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/dbsnp_138.hg38.vcf.gz.tbi

wget ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
wget ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi

############################################
# STEP 8: Base Quality Score Recalibration
############################################

echo "STEP 8: Base Quality Score Recalibration"

gatk BaseRecalibrator \
-I aligned_reads/SRR062634_dedup.bam \
-R support_files/hg38/hg38.fa \
--known-sites dbsnp_138.hg38.vcf.gz \
--known-sites Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
-O data/recal_data.table

gatk ApplyBQSR \
-I aligned_reads/SRR062634_dedup.bam \
-R support_files/hg38/hg38.fa \
--bqsr-recal-file data/recal_data.table \
-O aligned_reads/SRR062634_sorted_dedup_bqsr_reads.bam

############################################
# STEP 9: Alignment Metrics
############################################

echo "STEP 9: Collecting Insert Size Metrics"

gatk CollectInsertSizeMetrics \
-I aligned_reads/SRR062634_sorted_dedup_bqsr_reads.bam \
-O aligned_reads/insert_size_metrics.txt \
-H aligned_reads/insert_size_histogram.pdf

############################################
# STEP 10: Variant Calling
############################################

echo "STEP 10: Variant Calling"

gatk HaplotypeCaller \
-R support_files/hg38/hg38.fa \
-I aligned_reads/SRR062634_sorted_dedup_bqsr_reads.bam \
-O results/raw_variants.vcf

############################################
# STEP 11: Extract SNPs and INDELs
############################################

echo "STEP 11: Extracting SNPs and INDELs"

gatk SelectVariants \
-R support_files/hg38/hg38.fa \
-V results/raw_variants.vcf \
--select-type SNP \
-O results/raw_snps.vcf

gatk SelectVariants \
-R support_files/hg38/hg38.fa \
-V results/raw_variants.vcf \
--select-type INDEL \
-O results/raw_indels.vcf

############################################
# STEP 12: SNP Filtering
############################################

echo "STEP 12: Filtering SNPs"

gatk VariantFiltration \
-R support_files/hg38/hg38.fa \
-V results/raw_snps.vcf \
-O results/filtered_snps.vcf \
--filter-name "QD_filter" --filter-expression "QD < 2.0" \
--filter-name "FS_filter" --filter-expression "FS > 60.0" \
--filter-name "MQ_filter" --filter-expression "MQ < 40.0" \
--filter-name "SOR_filter" --filter-expression "SOR > 4.0" \
--filter-name "MQRankSum_filter" --filter-expression "MQRankSum < -12.5" \
--filter-name "ReadPosRankSum_filter" --filter-expression "ReadPosRankSum < -8.0" \
--genotype-filter-expression "DP < 10" --genotype-filter-name "DP_filter" \
--genotype-filter-expression "GQ < 20" --genotype-filter-name "GQ_filter"

############################################
# STEP 13: INDEL Filtering
############################################

echo "STEP 13: Filtering INDELs"

gatk VariantFiltration \
-R support_files/hg38/hg38.fa \
-V results/raw_indels.vcf \
-O results/filtered_indels.vcf \
--filter-name "QD_filter" --filter-expression "QD < 2.0" \
--filter-name "FS_filter" --filter-expression "FS > 200.0" \
--filter-name "SOR_filter" --filter-expression "SOR > 10.0" \
--genotype-filter-expression "DP < 10" --genotype-filter-name "DP_filter" \
--genotype-filter-expression "GQ < 20" --genotype-filter-name "GQ_filter"

############################################
# STEP 14: Select PASS Variants
############################################

echo "STEP 14: Selecting PASS Variants"

gatk SelectVariants \
--exclude-filtered \
-V results/filtered_snps.vcf \
-O results/passed-snps.vcf

gatk SelectVariants \
--exclude-filtered \
-V results/filtered_indels.vcf \
-O results/passed-indels.vcf

############################################
# STEP 15: Download Funcotator Data Sources
############################################

echo "STEP 15: Downloading Funcotator Data Sources"

gatk FuncotatorDataSourceDownloader \
--germline \
--hg38 \
--validate-integrity \
--extract-after-download

############################################
# STEP 16: Functional Annotation
############################################

echo "STEP 16: Annotating SNPs and INDELs"

gatk Funcotator \
--variant results/passed-snps.vcf \
--reference support_files/hg38/hg38.fa \
--ref-version hg38 \
--data-sources-path funcotator_dataSources.v1.8.hg38.20230908g \
--output results/passed-snps-funcotated.vcf \
--output-file-format VCF

gatk Funcotator \
--variant results/passed-indels.vcf \
--reference support_files/hg38/hg38.fa \
--ref-version hg38 \
--data-sources-path funcotator_dataSources.v1.8.hg38.20230908g \
--output results/passed-indels-funcotated.vcf \
--output-file-format VCF

############################################
# STEP 17: Export Variants to Table
############################################

echo "STEP 17: Exporting Variants to Table"

if [ -f results/passed-snps-funcotated.vcf ]; then

gatk VariantsToTable \
-V results/passed-snps-funcotated.vcf \
-F CHROM \
-F POS \
-F ID \
-F REF \
-F ALT \
-F QUAL \
-F FILTER \
-F AC \
-F AN \
-F DP \
-F AF \
-F FUNCOTATION \
-O results/output_snps.table

else

gatk VariantsToTable \
-V results/passed-snps.vcf \
-F CHROM \
-F POS \
-F ID \
-F REF \
-F ALT \
-F QUAL \
-F FILTER \
-F AC \
-F AN \
-F DP \
-F AF \
-O results/output_snps.table

fi

if [ -f results/passed-indels-funcotated.vcf ]; then

gatk VariantsToTable \
-V results/passed-indels-funcotated.vcf \
-F CHROM \
-F POS \
-F ID \
-F REF \
-F ALT \
-F QUAL \
-F FILTER \
-F AC \
-F AN \
-F DP \
-F AF \
-F FUNCOTATION \
-O results/output_indels.table

else

gatk VariantsToTable \
-V results/passed-indels.vcf \
-F CHROM \
-F POS \
-F ID \
-F REF \
-F ALT \
-F QUAL \
-F FILTER \
-F AC \
-F AN \
-F DP \
-F AF \
-O results/output_indels.table

fi

############################################
# Pipeline Completed
############################################

echo "==========================================="
echo "Pipeline Completed Successfully"
echo "==========================================="

