#!/usr/bin/env bash
action_saveCustom() {
    # Set default values
    image_prefix="${SPIN_BUILD_IMAGE_PREFIX:-"localhost"}"
    image_tag="${SPIN_BUILD_TAG:-"latest"}"
    vendor_name="spin"
    output_dir="./output"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                vendor_name="$2"
                shift 2
                ;;
            -t|--tag)
                image_tag="$2"
                shift 2
                ;;
            -p|--prefix)
                image_prefix="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: spin saveCustom [OPTIONS]"
                echo ""
                echo "Save Docker images built by 'spin custom' to a tarball for offline transfer."
                echo ""
                echo "Options:"
                echo "  -n, --name NAME      Vendor/project name for the archive (default: spin)"
                echo "  -t, --tag TAG        Image tag to save (default: latest)"
                echo "  -p, --prefix PREFIX  Image prefix (default: localhost)"
                echo "  -h, --help           Show this help message"
                echo ""
                echo "Output:"
                echo "  Archives are saved to: ./output/<name>-<timestamp>.tar"
                echo ""
                echo "Environment Variables:"
                echo "  SPIN_BUILD_IMAGE_PREFIX  Override default image prefix"
                echo "  SPIN_BUILD_TAG           Override default image tag"
                echo ""
                echo "Examples:"
                echo "  spin saveCustom                    # Creates ./output/spin-20231027-123456.tar"
                echo "  spin saveCustom --name spicy       # Creates ./output/spicy-20231027-123456.tar"
                echo "  spin saveCustom -n acme -t v1.0    # Creates ./output/acme-20231027-123456.tar"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use 'spin saveCustom --help' for usage information."
                return 1
                ;;
        esac
    done
    
    # Create output directory if it doesn't exist
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir"
        echo "📁 Created output directory: $output_dir"
        echo ""
    fi
    
    # Generate output filename
    output_file="${output_dir}/${vendor_name}-${image_tag}.tar"
    
    echo "🔍 Scanning for Docker images to save..."
    echo "📁 Current directory: $(pwd)"
    echo ""
    
    # Check if any Dockerfiles exist
    shopt -s nullglob
    dockerfiles=( Dockerfile* )
    shopt -u nullglob
    
    if [[ ${#dockerfiles[@]} -eq 0 ]]; then
        echo "❌ No Dockerfiles found in the current directory."
        echo "💡 Make sure you're in the project root where Dockerfiles are located."
        return 1
    fi

    echo "🐳 Found Dockerfile(s): ${dockerfiles[*]}"
    echo ""
    
    # Build list of images to save
    images_to_save=()
    missing_images=()
    
    for dockerfile in "${dockerfiles[@]}"; do
        # Generate image name (same logic as custom.sh)
        full_docker_image_name="${image_prefix}/$(echo "$dockerfile" | tr '[:upper:]' '[:lower:]')"
        image_with_tag="${full_docker_image_name}:${image_tag}"
        
        # Check if the image exists in local Docker
        if docker image inspect "$image_with_tag" &>/dev/null; then
            images_to_save+=("$image_with_tag")
            echo "✅ Found image: $image_with_tag"
        else
            missing_images+=("$image_with_tag")
            echo "⚠️  Image not found: $image_with_tag"
        fi
    done
    
    echo ""
    
    # Check if we have any images to save
    if [[ ${#images_to_save[@]} -eq 0 ]]; then
        echo "❌ No Docker images found to save."
        echo ""
        echo "💡 Did you run 'spin custom' to build the images first?"
        if [[ ${#missing_images[@]} -gt 0 ]]; then
            echo ""
            echo "Missing images:"
            for img in "${missing_images[@]}"; do
                echo "   - $img"
            done
        fi
        return 1
    fi
    
    # Warn about missing images
    if [[ ${#missing_images[@]} -gt 0 ]]; then
        echo "⚠️  Warning: Some images were not found and will be skipped:"
        for img in "${missing_images[@]}"; do
            echo "   - $img"
        done
        echo ""
    fi
    
    # Calculate total size of images
    echo "📊 Calculating image sizes..."
    total_size=0
    for img in "${images_to_save[@]}"; do
        size=$(docker image inspect "$img" --format='{{.Size}}')
        size_mb=$((size / 1024 / 1024))
        echo "   $img: ${size_mb} MB"
        total_size=$((total_size + size))
    done
    total_size_mb=$((total_size / 1024 / 1024))
    echo ""
    echo "📦 Total size: ${total_size_mb} MB"
    echo ""
    
    # Save images to tarball
    echo "💾 Saving ${#images_to_save[@]} image(s) to '$output_file'..."
    echo ""
    
    if docker image save -o "$output_file" "${images_to_save[@]}"; then
        # Get the actual file size
        if [[ -f "$output_file" ]]; then
            file_size=$(du -h "$output_file" | cut -f1)
            echo ""
            echo "✅ Successfully saved images to '$output_file'"
            echo "📦 Archive size: $file_size"
            echo ""
            echo "🚀 Next steps:"
            echo "   1. Copy '$output_file' to your USB stick"
            echo "   2. On the target server, run:"
            echo "      docker image load -i $output_file"
            echo ""
            echo "💡 To verify the archive contents, run:"
            echo "   tar -tvf $output_file | head -20"
            echo ""
            echo "📋 Images included in this archive:"
            for img in "${images_to_save[@]}"; do
                echo "   - $img"
            done
        else
            echo "❌ Error: Output file was not created."
            return 1
        fi
    else
        echo "❌ Failed to save images to '$output_file'."
        return 1
    fi
}