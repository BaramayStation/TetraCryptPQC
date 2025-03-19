from setuptools import setup, find_packages

setup(
    name="tetracryptpqc_nexus",
    version="0.1.0",
    description="A fully functional, future-proof post-quantum cryptographic system implementing higher-dimensional geometric encryption.",
    author="Your Name",
    author_email="your.email@example.com",
    packages=find_packages(include=['src', 'src.*']),
    install_requires=[
        "numpy",
        "scipy",
        "pyyggdrasil",
    ],
    entry_points={
        "console_scripts": [
            "tetracryptpqc=main:main",
        ],
    },
)
