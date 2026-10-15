import importlib.metadata
import importlib.util
import pathlib
import zipfile

import jpype

assert importlib.metadata.version("JPype1") == "1.7.1"
for module in ("pip", "ensurepip", "setuptools", "pkg_resources"):
    assert importlib.util.find_spec(module) is None, module

output = pathlib.Path("/tmp/poi-smoke.xlsx")
jpype.startJVM(jpype.getDefaultJVMPath(), "-Djava.class.path=/app/poi/*")

Workbook = jpype.JClass("org.apache.poi.xssf.usermodel.XSSFWorkbook")
FileOutputStream = jpype.JClass("java.io.FileOutputStream")

workbook = Workbook()
stream = FileOutputStream(str(output))
try:
    workbook.createSheet("smoke").createRow(0).createCell(0).setCellValue("ok")
    workbook.write(stream)
finally:
    stream.close()
    workbook.close()
    jpype.shutdownJVM()

with zipfile.ZipFile(output) as xlsx:
    assert "[Content_Types].xml" in xlsx.namelist()
    assert "xl/worksheets/sheet1.xml" in xlsx.namelist()

print(output)
