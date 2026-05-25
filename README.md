# Germline-Variant-Calling-Pipeline-using-GATK4
End-to-end germline variant analysis pipeline for human NGS sequencing data using GATK4, including preprocessing, BQSR, SNP/INDEL calling, filtering, functional annotation, and variant export on the hg38 reference genome.

# 1. GATK Installation and Setup

Official GATK Documentation: https://gatk.broadinstitute.org/
Download Link: https://github.com/broadinstitute/gatk/releases/download/4.6.2.0/gatk-4.6.2.0.zip

## Download GATK

```bash
wget https://github.com/broadinstitute/gatk/releases/download/4.6.2.0/gatk-4.6.2.0.zip
```

---

## Extract GATK Package

```bash
unzip gatk-4.6.2.0.zip
```

This will create the directory:

```text
gatk-4.6.2.0/
```

---

## Move into GATK Directory

```bash
cd gatk-4.6.2.0/
```

---

## Verify Java Installation

```bash
java -version
```

GATK requires Java 17 or higher.

---

## Test GATK Installation

```bash
./gatk --help
```

If GATK is installed correctly, the help menu will appear.

---

## Add GATK to PATH Permanently

Open `.bashrc`:

```bash
nano ~/.bashrc
```

Add the following line at the end of the file:

```bash
export PATH="/home/jazee/gatk-4.6.2.0/:$PATH"
```

Save and reload:

```bash
source ~/.bashrc
```

Verify installation:

```bash
gatk --help
```


```

---

# Installation Verification

To confirm successful installation:

```bash
gatk --version
```

Expected Output:

```text
The Genome Analysis Toolkit (GATK) v4.6.2.0
```
