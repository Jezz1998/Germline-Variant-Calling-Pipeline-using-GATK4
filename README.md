# Germline-Variant-Calling-Pipeline-using-GATK4

## Project Overview

End-to-end germline variant analysis pipeline for human NGS sequencing data using GATK4, including preprocessing, BQSR, SNP/INDEL calling, filtering, functional annotation, and variant export on the hg38 reference genome.

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
