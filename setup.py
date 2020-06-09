import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="TypeformETL",
    version="0.6",
    author="Avi Alkalay",
    author_email="avibrazil@gmail.com",
    description="Ingest all data from a Typeform account and put the data into a SQL database; can be run regularly to sync updates to DB",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/avibrazil/Typeform-ETL",
    install_requires=['sqlalchemy','pandas','requests','configobj'],
    data_files=[('share/TypeformETL/examples',['examples/datamodel.sql', 'examples/NPS Analysis.ipynb','examples/syncFromTypeform.conf.example'])],
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: OS Independent",
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Intended Audience :: Developers",
        "Intended Audience :: End Users/Desktop",
        "Intended Audience :: Information Technology",
        "License :: OSI Approved :: GNU Library or Lesser General Public License (LGPL)",
        "Operating System :: POSIX",
        "Topic :: Database",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Internet"
    ],
    python_requires='>=3.6',
)
