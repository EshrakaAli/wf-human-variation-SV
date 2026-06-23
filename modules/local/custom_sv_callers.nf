process RUN_CUTESV {
    container "quay.io/biocontainers/cutesv:2.1.1--py310h248e362_0"
    label "wgs"
    publishDir "${params.out_dir}/cutesv", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref_fasta

    output:
    tuple val(meta), path("${meta.sample_name}.cutesv.vcf"), emit: vcf

    script:
    """
    mkdir -p tmp_dir
    cuteSV \\
        ${bam} \\
        ${ref_fasta} \\
        ${meta.sample_name}.cutesv.vcf \\
        tmp_dir \\
        --threads ${task.cpus} \\
        --max_cluster_bias_HDD 100 \\
        --diff_ratio_merging_cluster 0.3
    """
}

process RUN_SVIM {
    container "quay.io/biocontainers/svim:2.0.0--py310hdfd78af_3"
    label "wgs"
    publishDir "${params.out_dir}/svim", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)
    path ref_fasta

    output:
    tuple val(meta), path("${meta.sample_name}.svim.vcf"), emit: vcf

    script:
    """
    svim alignment \\
        dir_svim \\
        ${bam} \\
        ${ref_fasta}
    
    mv dir_svim/variants.vcf ${meta.sample_name}.svim.vcf
    """
}

process MERGE_SVS {
    container "quay.io/biocontainers/survivor:1.0.7--h9a82719_6"
    publishDir "${params.out_dir}/survivor_consensus", mode: 'copy'

    input:
    // This tuple groups matching sample files together
    tuple val(meta), path(sniffles_vcf), path(cutesv_vcf), path(svim_vcf)

    output:
    tuple val(meta), path("${meta.sample_name}.consensus.vcf"), emit: consensus_vcf

    script:
    """
    # Write the paths of all 3 VCF files to a manifests list
    echo "${sniffles_vcf}" > vcf_list.txt
    echo "${cutesv_vcf}" >> vcf_list.txt
    echo "${svim_vcf}" >> vcf_list.txt

    # SURVIVOR merge parameters:
    # 1000: Max distance between breakpoints (1kb)
    # 2: Minimum callers required to support a variant (e.g., 2 out of 3)
    # 1: Take variant type into account (1=yes)
    # 1: Take variant strand into account (1=yes)
    # 0: Disabled estimate parameter
    # 30: Minimum size of variants to merge
    SURVIVOR merge vcf_list.txt 1000 2 1 1 0 30 ${meta.sample_name}.consensus.vcf
    """
}
