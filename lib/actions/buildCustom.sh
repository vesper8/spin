#!/usr/bin/env bash
action_buildCustom() {
  echo "buildCustom action executed with arguments: $@"

  # Run the build function
  build_images_only
}
 
# Extract the Docker build portion for debugging
build_images_only() {
    # Set default values
    build_platform="${SPIN_BUILD_PLATFORM:-"linux/amd64"}"
    image_prefix="${SPIN_BUILD_IMAGE_PREFIX:-"localhost"}"
    image_tag="${SPIN_BUILD_TAG:-"debug-$(date +%Y%m%d%H%M%S)"}"
    
    echo "🔍 Docker build context analysis:"
    echo "📁 Current directory: $(pwd)"
    echo ""
    
    # Check for .dockerignore file and display its contents
    dockerignore_files=()
    
    # Check current directory first
    if [[ -f ".dockerignore" ]]; then
        dockerignore_files+=("$(pwd)/.dockerignore")
    fi
    
    # Check parent directories (Docker searches up the tree)
    current_dir="$(pwd)"
    while [[ "$current_dir" != "/" ]]; do
        parent_dir="$(dirname "$current_dir")"
        if [[ -f "$parent_dir/.dockerignore" ]] && [[ "$parent_dir" != "$(pwd)" ]]; then
            dockerignore_files+=("$parent_dir/.dockerignore")
        fi
        current_dir="$parent_dir"
    done
    
    if [[ ${#dockerignore_files[@]} -gt 0 ]]; then
        echo "📋 Found .dockerignore file(s):"
        for ignore_file in "${dockerignore_files[@]}"; do
            echo "   📄 $ignore_file"
        done
        echo ""
        
        # Docker uses the .dockerignore in the build context directory
        primary_dockerignore="$(pwd)/.dockerignore"
        if [[ -f "$primary_dockerignore" ]]; then
            echo "🚫 Using .dockerignore file: $primary_dockerignore"
            echo "📝 Contents:"
            echo "----------------------------------------"
            cat "$primary_dockerignore" | nl -ba
            echo "----------------------------------------"
        else
            echo "⚠️  No .dockerignore in build context directory"
        fi
    else
        echo "❌ No .dockerignore file found!"
        echo "💡 Docker will include ALL files in the build context"
    fi
    echo ""
    
    # Show what files are in the build context (before .dockerignore filtering)
    echo "📦 Build context contents (before .dockerignore filtering):"
    echo "   Total files: $(find . -type f | wc -l)"
    echo "   Total size: $(du -sh . | cut -f1)"
    echo ""
    
    # Check if any Dockerfiles exist
    shopt -s nullglob
    dockerfiles=( Dockerfile* )
    shopt -u nullglob
    
    if [[ ${#dockerfiles[@]} -eq 0 ]]; then
        echo "❌ No Dockerfiles found in the current directory."
        exit 1
    fi

    echo "🐳 Found Dockerfile(s): ${dockerfiles[*]}"
    echo ""

    # Build each Dockerfile
    for dockerfile in "${dockerfiles[@]}"; do
        # Generate image name
        full_docker_image_name="${image_prefix}/$(echo "$dockerfile" | tr '[:upper:]' '[:lower:]')"
        versioned_image="${full_docker_image_name}:${image_tag}"

        echo "🔨 Building Docker image '$versioned_image' from '$dockerfile'..."
        echo "📋 Build context: $(pwd)"
        echo "🚫 .dockerignore: $([ -f .dockerignore ] && echo "Active" || echo "None")"
        echo ""
        
        # Build the Docker image locally with verbose output to see what's being copied
        echo "🚀 Starting build (you'll see what files are being processed)..."
        if docker buildx build --platform "$build_platform" \
            -t "$versioned_image" \
            -f "$dockerfile" \
            --load \
            --progress=plain \
            .; then
            echo ""
            echo "✅ Successfully built '$versioned_image' from '$dockerfile'"
            echo ""
            echo "🔍 Debug commands you can run:"
            echo "   # Interactive shell in the image:"
            echo "   docker run --rm -it $versioned_image /bin/sh"
            echo ""
            echo "   # List all files in the image:"
            echo "   docker run --rm $versioned_image find / -type f 2>/dev/null | grep -v '^/proc\\|^/sys\\|^/dev\\|^/run'"
            echo ""
            echo "   # Show image layers and sizes:"
            echo "   docker history $versioned_image"
            echo ""
            echo "   # Detailed image inspection:"
            echo "   docker image inspect $versioned_image"
            echo ""
        else
            echo "❌ Failed to build '$versioned_image' from '$dockerfile'."
            exit 1
        fi
        echo "----------------------------------------"
    done
    
    echo "🎉 All images built successfully for local inspection!"
    echo ""
    echo "💡 Tips for debugging .dockerignore issues:"
    echo "   1. Check the file paths are relative to the build context"
    echo "   2. Use '**/' for recursive directory matching"
    echo "   3. Use '!' to negate/include files that were previously ignored"
    echo "   4. Remember that .dockerignore uses Go's filepath.Match rules"
}

# Function to test what would be ignored
test_dockerignore() {
    if [[ -f ".dockerignore" ]]; then
        echo "🧪 Testing .dockerignore patterns:"
        echo "📁 Files that would be INCLUDED in build context:"
        # This is a simplified test - actual Docker behavior may vary
        find . -type f | while read -r file; do
            excluded=false
            while IFS= read -r pattern; do
                # Skip empty lines and comments
                [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
                
                # Simple pattern matching (this is a approximation)
                if [[ "$file" == *"$pattern"* ]] || [[ "$file" =~ $pattern ]]; then
                    excluded=true
                    break
                fi
            done < .dockerignore
            
            if [[ "$excluded" == false ]]; then
                echo "   ✅ $file"
            fi
        done
        echo ""
        echo "📁 Files that would be EXCLUDED:"
        find . -type f | while read -r file; do
            excluded=false
            while IFS= read -r pattern; do
                [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
                if [[ "$file" == *"$pattern"* ]] || [[ "$file" =~ $pattern ]]; then
                    excluded=true
                    break
                fi
            done < .dockerignore
            
            if [[ "$excluded" == true ]]; then
                echo "   ❌ $file"
            fi
        done
    fi
}

# Check if user wants to test .dockerignore patterns
if [[ "$1" == "--test-ignore" ]]; then
    test_dockerignore
    exit 0
fi