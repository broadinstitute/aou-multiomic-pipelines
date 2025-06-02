version 1.0

import "../../common/structs.wdl"


task PCA {
    meta {
        description: "Perform Principal Component Analysis (PCA) on an AnnData dataset."
        author: "Lucas van Dijk"
        email: "lvandijk@broadinstitute.org"
    }
    
    input {
        String input_file
        String? input_layer
        String? output_url
        Int? num_components
        RuntimeAttr? runtime_attr_override
    }
    
    parameter_meta {
        input_file: "Path to the input file for PCA analysis. Should be a URL to an anndata file in Zarr format."
        input_layer: "AnnData layer to use for PCA. If not specified, the data in the .X attribute will be used."
        output_url: "URL to save the PCA results. If not specified, the input file will be overwritten with the results."
        num_components: "Number of principal components to compute. If not specified, defaults to the minimum of the number of samples and features."
        
        runtime_attr_override: "Optional runtime attributes for the task, including memory, CPU cores, disk space, and Docker image."
    }
    
    
    RuntimeAttr runtime_attr_default = object {
        mem_gb: 4,
        cpu_cores: 2,
        disk_gb: 20,
        boot_disk_gb: 20,
        preemptible_tries: 3,
        max_retries: 3,
        docker: "us-central1-docker.pkg.dev/broad-dsp-lrma/aou-multiomics/omelix:latest"
    }
    
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, runtime_attr_default])
     
    
    command <<<
        set -euo pipefail
        
        omelix pca \
            --save --print-expl-var-ratio \
            ~{if defined(input_layer) then "-l ~{input_layer}" else ""} \
            ~{if defined(output_url) then "--output-path ~{output_url}" else ""} \
            ~{if defined(num_components) then "-n ~{num_components}" else ""} \
            ~{input_file} > expl_var_ratios.tsv
    >>>
    
    runtime {
        cpu: select_first([runtime_attr.cpu_cores, runtime_attr_default.cpu_cores])
        memory: select_first([runtime_attr.mem_gb, runtime_attr_default.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, runtime_attr_default.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, runtime_attr_default.boot_disk_gb])
        preemptible: select_first([runtime_attr.preemptible_tries, runtime_attr_default.preemptible_tries])
        maxRetries: select_first([runtime_attr.max_retries, runtime_attr_default.max_retries])
        docker: select_first([runtime_attr.docker, runtime_attr_default.docker])
    }
     
    # By default, overwrite the input data set
    String output_url_ret = select_first([output_url, input_file])
    
    output {
        String url_out = output_url_ret
        Array[Float] expl_var_ratios = read_tsv("expl_var_ratios.tsv")[0]
    }
}

task PermutedPCA {
    meta {
        description: "Perform Principal Component Analysis (PCA) on a randomly permuted AnnData dataset."
        author: "Lucas van Dijk"
        email: "lvandijk@broadinstitute.org"
    }
    
    input {
        String input_file
        String? input_layer
        Int? num_components
        
        RuntimeAttr? runtime_attr_override
    }
    
    parameter_meta {
        input_file: "Path to the input file for PCA analysis. Should be a URL to an anndata file in Zarr format."
        input_layer: "AnnData layer to use for PCA. If not specified, the data in the .X attribute will be used."
        num_components: "Number of principal components to compute. If not specified, defaults to the minimum of the number of samples and features."
        
        runtime_attr_override: "Optional runtime attributes for the task, including memory, CPU cores, disk space, and Docker image."
    }
    
    
    RuntimeAttr runtime_attr_default = object {
        mem_gb: 4,
        cpu_cores: 2,
        disk_gb: 20,
        boot_disk_gb: 20,
        preemptible_tries: 3,
        max_retries: 3,
        docker: "us-central1-docker.pkg.dev/broad-dsp-lrma/aou-multiomics/omelix:latest"
    }
    
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, runtime_attr_default])
     
    
    command <<<
        set -euo pipefail
        
        omelix pca \
            --permute --print-expl-var-ratio \
            ~{if defined(input_layer) then "-l ~{input_layer}" else ""} \
            ~{if defined(num_components) then "-n ~{num_components}" else ""} \
            ~{input_file} > expl_var_ratios.tsv
    >>>
    
    runtime {
        cpu: select_first([runtime_attr.cpu_cores, runtime_attr_default.cpu_cores])
        memory: select_first([runtime_attr.mem_gb, runtime_attr_default.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, runtime_attr_default.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, runtime_attr_default.boot_disk_gb])
        preemptible: select_first([runtime_attr.preemptible_tries, runtime_attr_default.preemptible_tries])
        maxRetries: select_first([runtime_attr.max_retries, runtime_attr_default.max_retries])
        docker: select_first([runtime_attr.docker, runtime_attr_default.docker])
    }
    
    output {
        Array[Float] expl_var_ratios = read_tsv("expl_var_ratios.tsv")[0]
    }
}

task BuyaEyubogluThreshold {
    meta {
        description: "Calculate the Buya and Eyuboglu threshold, i.e., the number of significant principal components."
        author: "Lucas van Dijk"
        email: "lvandijk@broadinstitute.org"
    }

    input {
        Array[Array[Float]] perm_expl_var_ratios
        Array[Float] orig_expl_var_ratios
        
        Float significance = 0.05
        
        RuntimeAttr? runtime_attr_override
    }
    
    parameter_meta {
        perm_expl_var_ratios: "Array of arrays containing the explained variance ratios from permuted PCA runs."
        orig_expl_var_ratios: "Array containing the explained variance ratios from the PCA on the original data."
        significance: "Significance level for determining the threshold. Default is 0.05."
    }
    
    RuntimeAttr runtime_attr_default = object {
        mem_gb: 2,
        cpu_cores: 1,
        disk_gb: 20,
        boot_disk_gb: 20,
        preemptible_tries: 3,
        max_retries: 3,
        docker: "us-central1-docker.pkg.dev/broad-dsp-lrma/aou-multiomics/omelix:latest"
    }
    
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, runtime_attr_default])
    
    File perm_expl_var_file = write_tsv(perm_expl_var_ratios)
    File orig_expl_var_file = write_tsv([orig_expl_var_ratios])
    Int num_perm = length(perm_expl_var_ratios)
    
    command <<<
        set -euo pipefail
        
        python3 - <<EOF
            import numpy as np
            
            perm_expl_var_ratios = np.loadtxt("~{perm_expl_var_file}", delimiter="\\t")
            orig_expl_var_ratios = np.loadtxt("~{orig_expl_var_file}", delimiter="\\t")[0]
            
            pvalues = ((np.sum(perm_expl_var_ratios >= orig_expl_var_ratios, axis=0) + 1) 
                        / (~{num_perm} + 1))
                    
            for i in range (1, len(pvalues)):
                if pvalues[i] <= pvalues[i-1]:
                    pvalues[i] = pvalues[i-1]
            
            num_components = np.sum(pvalues < ~{significance})
            
            print(num_components)
        EOF
    >>>
    
    runtime {
        cpu: select_first([runtime_attr.cpu_cores, runtime_attr_default.cpu_cores])
        memory: select_first([runtime_attr.mem_gb, runtime_attr_default.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, runtime_attr_default.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, runtime_attr_default.boot_disk_gb])
        preemptible: select_first([runtime_attr.preemptible_tries, runtime_attr_default.preemptible_tries])
        maxRetries: select_first([runtime_attr.max_retries, runtime_attr_default.max_retries])
        docker: select_first([runtime_attr.docker, runtime_attr_default.docker])
    }
    
    output {
        Int num_components = read_int(stdout())
    }
}