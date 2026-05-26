# GATK Germline Variant Calling Pipeline (hg38)

## Project Overview

This repository contains a complete GATK-based germline variant calling workflow for Illumina paired-end whole genome sequencing (WGS) data.

The workflow includes:

- Quality Control (FastQC)
- Read Alignment using BWA-MEM
- Duplicate Marking
- Base Quality Score Recalibration (BQSR)
- Variant Calling using HaplotypeCaller
- SNP and INDEL Filtering
- Functional Annotation using Funcotator
- Variant Export to Table Format

---

# Dataset Information

* **Sample ID:** HG00096
* **Read Accession:** SRR062634
* **Platform:** Illumina
* **Reference Genome:** hg38
* **Pipeline Type:** Germline Variant Calling

FASTQ files were downloaded from the 1000 Genomes Project.

---

# Workflow Overview

FASTQ Reads  
↓  
Quality Control (FastQC)  
↓  
Reference Genome Preparation  
↓  
Read Alignment using BWA-MEM  
↓  
MarkDuplicates  
↓  
Base Quality Score Recalibration (BQSR)  
↓  
Variant Calling using HaplotypeCaller  
↓  
SNP and INDEL Extraction  
↓  
Variant Filtering  
↓  
Variant Annotation using Funcotator  
↓  
Export Variants to Table Format  

---

# Complete Pipeline

## 1. Directory Setup

```bash
mkdir -p ngs_variant_project/{reads,aligned_reads,results,data,support_files/hg38}

cd ngs_variant_project/
```

---

## 2. Download FASTQ Reads

```bash
wget -P reads \
ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_1.filt.fastq.gz

wget -P reads \
ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_2.filt.fastq.gz
```

---

## 3. Download Reference Genome (hg38)

```bash
wget -P support_files/hg38 \
https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
```

Extract the genome:

```bash
gunzip support_files/hg38/hg38.fa.gz
```

---

## 4. Create Reference Index Files

### FASTA Index (.fai)

```bash
samtools faidx support_files/hg38/hg38.fa
```

### Sequence Dictionary (.dict)

```bash
gatk CreateSequenceDictionary \
-R support_files/hg38/hg38.fa \
-O support_files/hg38/hg38.dict
```

---

## 5. Quality Control using FastQC

```bash
fastqc reads/SRR062634_1.filt.fastq.gz -o reads/

fastqc reads/SRR062634_2.filt.fastq.gz -o reads/
```

---

## 6. Mapping with BWA-MEM

Index the reference genome:

```bash
bwa index support_files/hg38/hg38.fa
```

Align paired-end reads:

```bash
bwa mem -t 8 \
-R "@RG\tID:SRR062634\tSM:HG00096\tPL:ILLUMINA\tLB:lib1\tPU:unit1" \
support_files/hg38/hg38.fa \
reads/SRR062634_1.filt.fastq.gz \
reads/SRR062634_2.filt.fastq.gz \
> aligned_reads/SRR062634.paired.sam
```

---

## 7. Mark Duplicates

```bash
gatk MarkDuplicatesSpark \
-I aligned_reads/SRR062634.paired.sam \
-O aligned_reads/SRR062634_dedup.bam \
-M aligned_reads/SRR062634_dup_metrics.txt
```

---

# Base Quality Score Recalibration (BQSR)

## 8. Download Known Variant Sites

```bash
wget \
ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz

wget \
ftp://gsapubftp-anonymous@ftp.broadinstitute.org/bundle/hg38/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz.tbi
```

---

## 9. Generate Recalibration Table

```bash
gatk BaseRecalibrator \
-I aligned_reads/SRR062634_dedup.bam \
-R support_files/hg38/hg38.fa \
--known-sites dbsnp_138.hg38.vcf.gz \
--known-sites Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
-O data/recal_data.table
```

---

## 10. Apply BQSR

```bash
gatk ApplyBQSR \
-I aligned_reads/SRR062634_dedup.bam \
-R support_files/hg38/hg38.fa \
--bqsr-recal-file data/recal_data.table \
-O aligned_reads/SRR062634_sorted_dedup_bqsr_reads.bam
```

---

# Alignment Metrics

## 11. Collect Insert Size Metrics

```bash
gatk CollectInsertSizeMetrics \
-I aligned_reads/SRR062634_sorted_dedup_bqsr_reads.bam \
-O aligned_reads/insert_size_metrics.txt \
-H aligned_reads/insert_size_histogram.pdf
```

---

# Variant Calling

## 12. Run HaplotypeCaller

```bash
gatk HaplotypeCaller \
-R support_files/hg38/hg38.fa \
-I aligned_reads/SRR062634_sorted_dedup_bqsr_reads.bam \
-O results/raw_variants.vcf
```

---

# SNP and INDEL Extraction

## 13. Extract SNPs

```bash
gatk SelectVariants \
-R support_files/hg38/hg38.fa \
-V results/raw_variants.vcf \
--select-type SNP \
-O results/raw_snps.vcf
```

---

## 14. Extract INDELs

```bash
gatk SelectVariants \
-R support_files/hg38/hg38.fa \
-V results/raw_variants.vcf \
--select-type INDEL \
-O results/raw_indels.vcf
```

---

# Variant Filtering

## 15. Filter SNPs

```bash
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
--genotype-filter-expression "DP < 10" \
--genotype-filter-name "DP_filter" \
--genotype-filter-expression "GQ < 20" \
--genotype-filter-name "GQ_filter"
```

---

## 16. Filter INDELs

```bash
gatk VariantFiltration \
-R support_files/hg38/hg38.fa \
-V results/raw_indels.vcf \
-O results/filtered_indels.vcf \
--filter-name "QD_filter" --filter-expression "QD < 2.0" \
--filter-name "FS_filter" --filter-expression "FS > 200.0" \
--filter-name "SOR_filter" --filter-expression "SOR > 10.0" \
--genotype-filter-expression "DP < 10" \
--genotype-filter-name "DP_filter" \
--genotype-filter-expression "GQ < 20" \
--genotype-filter-name "GQ_filter"
```

---

# Select PASS Variants

## 17. Extract Passed SNPs

```bash
gatk SelectVariants \
--exclude-filtered \
-V results/filtered_snps.vcf \
-O results/passed-snps.vcf
```

---

## 18. Extract Passed INDELs

```bash
gatk SelectVariants \
--exclude-filtered \
-V results/filtered_indels.vcf \
-O results/passed-indels.vcf
```

---

# Variant Annotation using Funcotator

## 19. Download Funcotator Data Sources

```bash
gatk FuncotatorDataSourceDownloader \
--germline \
--hg38 \
--validate-integrity \
--extract-after-download
```

---

## 20. Annotate SNPs

```bash
gatk Funcotator \
--variant results/passed-snps.vcf \
--reference support_files/hg38/hg38.fa \
--ref-version hg38 \
--data-sources-path funcotator_dataSources.v1.8.hg38.20230908g \
--output results/passed-snps-funcotated.vcf \
--output-file-format VCF
```

---

## 21. Annotate INDELs

```bash
gatk Funcotator \
--variant results/passed-indels.vcf \
--reference support_files/hg38/hg38.fa \
--ref-version hg38 \
--data-sources-path funcotator_dataSources.v1.8.hg38.20230908g \
--output results/passed-indels-funcotated.vcf \
--output-file-format VCF
```

---

# Export Variants to Table Format

## 22. Convert SNP VCF to Table

```bash
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
```

---

## 23. Convert INDEL VCF to Table

```bash
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
```

---

# Final Outputs

The pipeline generates:

* Filtered SNP VCF
* Filtered INDEL VCF
* Funcotator Annotated VCF
* Variant Tables
* Insert Size Metrics
* QC Reports

---

# Tools Used

* GATK v4.6.2.0
* BWA-MEM
* SAMtools
* FastQC
* Funcotator

---

# Reference Genome

* Human Genome Reference Consortium Build 38 (hg38)

---

# Notes

* Variant filtering thresholds were based on GATK Best Practices.
* Funcotator annotation is optional but recommended.
* Further downstream analysis can be performed using R, Python, Excel, or visualization tools.
