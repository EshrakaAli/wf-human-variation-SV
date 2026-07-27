process RUN_CUTESV {
    container "quay.io/biocontainers/cutesv:2.1.1--pyhdfd78af_0"
    label "wgs"
    publishDir "${params.out_dir}/cutesv", mode: 'copy'

    input:
    tuple path(xam), path(xam_idx), val(xam_meta)
    file tr_bed
    tuple path(ref), path(ref_idx), path(ref_cache), env(REF_PATH)
    val genome_build

    output:
    tuple val(xam_meta), path("${xam_meta.alias}.cutesv.vcf"), emit: vcf

    script:
    """
    mkdir -p tmp_dir

    cuteSV \
        ${xam} \
        ${ref} \
        ${xam_meta.alias}.cutesv.vcf \
        tmp_dir \
        --threads ${task.cpus} \
        --max_cluster_bias_INS 1000 \
        --sample ${xam_meta.alias}_cutesv \
        --diff_ratio_merging_INS 0.3
    """
}

process RUN_SVIM {
    container "quay.io/biocontainers/svim:2.0.0--pyhdfd78af_0"
    label "wgs"
    publishDir "${params.out_dir}/svim", mode: 'copy'

    input:
    tuple path(xam), path(xam_idx), val(xam_meta)
    file tr_bed
    tuple path(ref), path(ref_idx), path(ref_cache), env(REF_PATH)
    val genome_build

    output:
    tuple val(xam_meta), path("${xam_meta.alias}.svim.vcf"), emit: vcf

    script:
    """
svim alignment \
    dir_svim \
    ${xam} \
    ${ref}

mv dir_svim/variants.vcf ${xam_meta.alias}.svim.vcf
"""
}

process MERGE_SVS {
    container "quay.io/biocontainers/survivor:1.0.7--he513fc3_0"
    publishDir "${params.out_dir}/survivor_consensus", mode: 'copy'

    input:
    tuple val(meta), path(sniffles_vcf), path(cutesv_vcf), path(svim_vcf)

    output:
    tuple val(meta), path("${meta.alias}.consensus.vcf"), emit: consensus_vcf

    script:
    """
    printf "%s\n" \
        ${sniffles_vcf} \
        ${cutesv_vcf} \
        ${svim_vcf} > vcf_list.txt

    SURVIVOR merge \
        vcf_list.txt \
        1000 \
        1 \
        1 \
        1 \
        0 \
        30 \
        ${meta.alias}.consensus.vcf
    """
}

// modules/local/custom_sv_callers.nf

process MERGE_JASMINE {
    container 'eshrakaali/jasmine:1.1.5'
    
input:
tuple val(meta),
      path(sniffles_vcf),
      path(cutesv_vcf),
      path(svim_vcf),
      path(genome)
    
    output:
    path "${sample}.jasmine.vcf", emit: jasmine_vcf
    
    script:
    def vcf_list = vcf_files.collect{ it.getName() }.join(',')
    
    """
    echo "Processing sample: ${sample}"
    echo "VCF files: ${vcf_list}"
    echo "Genome file: ${genome}"
    
    # Check if VCF files exist and have content
    for vcf in ${vcf_files.join(' ')}; do
        if [ ! -f "\$vcf" ]; then
            echo "ERROR: VCF file not found: \$vcf"
            exit 1
        fi
        VAR_COUNT=\$(grep -v "^#" \$vcf | wc -l)
        echo "Found VCF: \$vcf (variants: \$VAR_COUNT)"
        if [ \$VAR_COUNT -eq 0 ]; then
            echo "WARNING: \$vcf has no variants"
        fi
    done
    
    # Run Jasmine with comma-separated file list
    jasmine \
        --comma_filelist ${vcf_list} \
        out_file=${sample}.jasmine.vcf \
        genome_file=${genome} \
        max_dist=5000 \
        min_support=1 \
        --normalize_type \
        --normalize_chrs \
        --default_zero_genotype
    
    # Check if output was created
    if [ ! -f ${sample}.jasmine.vcf ]; then
        echo "ERROR: ${sample}.jasmine.vcf not created!"
        ls -la
        exit 1
    fi
    
    echo "Successfully created ${sample}.jasmine.vcf"
    echo "Merged variants: \$(grep -v "^#" ${sample}.jasmine.vcf | wc -l)"
    """
}
