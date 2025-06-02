version 1.0

import "../../tasks/preprocessing/pca.wdl" as PCA

workflow PCAWithBuyaEyuboglu {
    input {
        String input_file
        String? input_layer
        String? output_url
        Int? num_components
        Int? num_permutations
    }
    
    Int num_perm = select_first([num_permutations, 20])
    scatter(i in range(num_perm)) {
        call PCA.PermutedPCA {
            input:
                input_file = input_file,
                input_layer = input_layer,
                num_components = num_components,
        }
    }

    call PCA.PCA as OrigPCA {
        input:
            input_file = input_file,
            input_layer = input_layer,
            output_url = output_url,
            num_components = num_components,
    }
    
    call PCA.BuyaEyubogluThreshold {
        input:
            perm_expl_var_ratios = PermutedPCA.expl_var_ratios,
            orig_expl_var_ratios = OrigPCA.expl_var_ratios,
    }
    
    String output_ret = select_first([output_url, input_file])
    
    output {
        Int threshold = BuyaEyubogluThreshold.num_components
        String output_path = output_ret
    }
}