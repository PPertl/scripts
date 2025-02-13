#!/bin/bash

# This file will be sourced in init.sh

# https://raw.githubusercontent.com/ai-dock/comfyui/main/config/provisioning/default.sh

# Packages are installed after nodes so we can fix them...

PYTHON_PACKAGES=(
    #"opencv-python==4.7.0.72"
)

NODES=(
    "https://github.com/PPertl/ComfyUI-Manager"
    "https://github.com/PPertl/comfyui-art-venture"
    "https://github.com/PPertl/comfyui_segment_anything"
    "https://github.com/PPertl/ComfyUI-Impact-Pack"
    "https://github.com/PPertl/comfy_PoP"
    "https://github.com/PPertl/prompt_injection"
    "https://github.com/PPertl/ComfyUI_IPAdapter_plus"
    "https://github.com/PPertl/comfyui_controlnet_aux"
    "https://github.com/PPertl/image-resize-comfyui"
    "https://github.com/PPertl/ComfyUI_essentials"
    "https://github.com/PPertl/LCM_Inpaint_Outpaint_Comfy"
    "https://github.com/PPertl/ComfyUI-KJNodes"
    "https://github.com/PPertl/comfyui-ultralytics-yolo"
)

IPADAPTER_MODELS=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter_sdxl_vit-h.safetensors"
) #ipadapter

CLIPVISION_MODELS=(
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"
) #clip_vision

CHECKPOINT_MODELS=(
    "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors"
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
)

UNET_MODELS=(
    "https://huggingface.co/diffusers/stable-diffusion-xl-1.0-inpainting-0.1/resolve/main/unet/diffusion_pytorch_model.safetensors"
) #unet

LORA_MODELS=(

)

VAE_MODELS=(

)

UPSCALE_MODELS=(

)

CONTROLNET_MODELS=(
    "https://huggingface.co/thibaud/controlnet-openpose-sdxl-1.0/resolve/main/OpenPoseXL2.safetensors"
)

ULTRALYTICS=(
    "https://huggingface.co/jags/yolov8_model_segmentation-set/resolve/main/face_yolov8m-seg_60.pt"
    "https://huggingface.co/jags/yolov8_model_segmentation-set/resolve/main/face_yolov8n-seg2_60.pt"
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt"
)

ANNOTATORS=(
    "https://huggingface.co/lllyasviel/Annotators/resolve/main/hand_pose_model.pth"
    "https://huggingface.co/lllyasviel/Annotators/resolve/main/facenet.pth"
    "https://huggingface.co/lllyasviel/Annotators/resolve/main/body_pose_model.pth"
)


### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    DISK_GB_AVAILABLE=$(($(df --output=avail -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_USED=$(($(df --output=used -m "${WORKSPACE}" | tail -n1) / 1000))
    DISK_GB_ALLOCATED=$(($DISK_GB_AVAILABLE + $DISK_GB_USED))
    provisioning_print_header
    provisioning_get_nodes
    provisioning_install_python_packages
    copyModels
    provisioning_print_end
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    micromamba -n comfyui run ${PIP_INSTALL} -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                micromamba -n comfyui run ${PIP_INSTALL} -r "${requirements}"
            fi
        fi
    done
}

function provisioning_install_python_packages() {
    if [ ${#PYTHON_PACKAGES[@]} -gt 0 ]; then
        micromamba -n comfyui run ${PIP_INSTALL} ${PYTHON_PACKAGES[*]}
    fi
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi
    dir="$1"
    mkdir -p "$dir"
    shift
    if [[ $DISK_GB_ALLOCATED -ge $DISK_GB_REQUIRED ]]; then
        arr=("$@")
    else
        printf "WARNING: Low disk space allocation - Only the first model will be downloaded!\n"
        arr=("$1")
    fi

    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"

        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
}

function copyModels() {
    if [[ -n "${DOWNLOAD_MODELS}" ]]; then
        downloadModels
    elif [[ -n "${DOWNLOAD_MODELS_THEN_COPY}" ]]; then
        downloadModelsThenCopy
    else
        copyFromNetworkVolume
    fi
}

COMFY_BASEPATH="/opt/ComfyUI"

function downloadModels() {
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/ipadapter" \
        "${IPADAPTER_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/clip_vision" \
        "${CLIPVISION_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/loras" \
        "${LORA_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/upscale_models" \
        "${UPSCALE_MODELS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/models/ultralytics/segm" \
        "${ULTRALYTICS[@]}"
    provisioning_get_models \
        "${COMFY_BASEPATH}/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators" \
        "${ANNOTATORS[@]}"
}

function downloadModelsThenCopy() {
    downloadModels
    mkdir -p /network-volume/ComfyUI/models
    cp -r /opt/ComfyUI/models /network-volume/ComfyUI/

    mkdir -p /network-volume/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators
    cp -r /opt/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators /network-volume/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/
}

function copyFromNetworkVolume() {
    cp -r /network-volume/ComfyUI/models/ /opt/ComfyUI
    mkdir -p /opt/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators
    cp -r /network-volume/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/Annotators/ /opt/ComfyUI/custom_nodes/comfyui_controlnet_aux/ckpts/lllyasviel/
}

provisioning_start
