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

process MERGE_JASMINE {

    container "eshrakaali/jasmine:1.1.5"
    containerOptions '--user 1118:1118'

    input:
    tuple val(meta),
          path(sniffles_vcf),
          path(cutesv_vcf),
          path(svim_vcf),
          path(ref),
          path(ref_idx),
          path(ref_cache)

    output:
    path "${meta.alias}.jasmine.vcf", emit: jasmine_vcf

    script:
    """
    printf "%s\n" \
        ${sniffles_vcf} \
        ${cutesv_vcf} \
        ${svim_vcf} > vcf_list.txt

java -jar /opt/jasmine/jasmine.jar \
    file_list=vcf_list.txt \
    out_file=${meta.alias}.jasmine.vcf \
    genome_file=${ref} \
    max_dist=5000 \
    min_support=1 \
    --normalize_type \
    --normalize_chrs
    """
}
