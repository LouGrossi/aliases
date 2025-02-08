function cdk-create-extension {
  # Default values
  local DIR="."
  local NAME="aws-cdk-extension"
  local VERSION="1.0.0"
  local DESCRIPTION="Custom AWS CDK CLI extension"
  local AUTHOR="Your Name"
  local AUTHOR_EMAIL="your.email@example.com"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --parameters)
        IFS=',' read -r NAME VERSION DESCRIPTION AUTHOR AUTHOR_EMAIL <<<"$2"
        shift 2
        ;;
      --help)
        echo "Usage: cdk-create-extension [DIRECTORY] [--parameters name,version,description,author,author_email]"
        echo
        echo "Creates a boilerplate structure for an AWS CDK CLI extension."
        echo
        echo "Arguments:"
        echo "  DIRECTORY       The root directory for the extension (default: current directory)."
        echo "  --parameters    Comma-separated values for setup.py fields:"
        echo "                  name, version, description, author, author_email"
        echo
        echo "Example:"
        echo "  cdk-create-extension ./my-extension"
        echo "  cdk-create-extension --parameters aws-cdk-custom,1.0.1,\"My Extension\",\"Jane Doe\",jane.doe@example.com"
        return 0
        ;;
      *)
        DIR="$1"
        shift
        ;;
    esac
  done

  # Summarize actions
  echo "AWS CDK Extension Creation Summary:"
  echo "-----------------------------------"
  echo "Directory:       $DIR"
  echo "Name:            $NAME"
  echo "Version:         $VERSION"
  echo "Description:     $DESCRIPTION"
  echo "Author:          $AUTHOR"
  echo "Author Email:    $AUTHOR_EMAIL"
  echo
  echo "This will create a boilerplate structure for an AWS CDK CLI extension."
  echo "You can modify the generated files later if needed."
  echo
  read "CONFIRM?Proceed with creation? [y/N]: "
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    return 1
  fi

  # Create directory structure
  mkdir -p "$DIR"/{aws_cdk_extension,bin,tests,descriptions}
  touch "$DIR"/README.md
  touch "$DIR"/aws_cdk_extension/__init__.py
  touch "$DIR"/tests/test_main.py

  # Generate setup.py
  cat > "$DIR/setup.py" <<EOF
from setuptools import setup, find_packages

setup(
    name="$NAME",
    version="$VERSION",
    description="$DESCRIPTION",
    author="$AUTHOR",
    author_email="$AUTHOR_EMAIL",
    packages=find_packages(),
    entry_points={
        'console_scripts': [
            'cdk-extension=aws_cdk_extension.main:main',
        ]
    },
    install_requires=[
        'boto3',
    ],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    python_requires='>=3.7',
)
EOF

  # Generate README.md
  cat > "$DIR/README.md" <<EOF
# $NAME

$DESCRIPTION

## Getting Started

Install the package locally:

\`\`\`bash
pip install -e .
\`\`\`

Run the command:

\`\`\`bash
cdk-extension <args>
\`\`\`
EOF

  # Generate main.py (generic template)
  cat > "$DIR/aws_cdk_extension/main.py" <<EOF
import argparse

def main():
    """
    Entry point for the custom AWS CDK CLI extension.
    """
    parser = argparse.ArgumentParser(description="$DESCRIPTION")
    parser.add_argument('action', help="The action to perform", choices=['example'])
    args = parser.parse_args()

    if args.action == 'example':
        print("This is an example command! Replace with your custom logic.")

if __name__ == '__main__':
    main()
EOF

  echo "AWS CDK extension structure created successfully in $DIR."
  echo "You can now modify the files as needed."
  echo "To install the extension locally, run:"
  echo "  pip install -e $DIR"
}
