version 1.0

import "../../common/structs.wdl"

task ImputeMissing {
    input {
        String olink_input
        
        RuntimeAttr? runtime_attr
    }
    
    parameter_meta {
        olink_input: "Path to the Olink input file containing missing values. Should be a URL to an anndata file in Zarr format."
    }
    
    command <<<
        
    >>>
}