# db2git
### ��������
������ PowerShell ��� ��������������� ��������������� �������� ���� ������ SQL Server
### ��������� � ���������
1. ���������� ���� ����������� (����������� �������)
1. �������� GIT-����������� ��� �������� ������� �������� SQL-������� (����������� ����).
1. ���������� ����������� ����.
1. �������� � ��������� � �������� � ������������ ���� settings.ini ���������� ����:
    ```ini
    [General]
    ScriptRepository=git@v-deploy.transasia.ru:soloviov.ae/db2git.git
    DirectoryToSaveTo=<������� � ������������ ����>
    [DB]
    ServerName=��� SQL-�������
    Database=��� ���� ������
    Login=����� ������������ SQL-������� (�������������� SQL Server)
    Password=������ ������������ SQL-������� (�������������� SQL Server)
    ExcludeSchemas=sys,Information_Schema 
    ```
1.  ��������� ���� launcher.ps1 � PowerShell ��� �������� ����������� ������� �� ��������� ��������: 
    ```ps
    powershell -ExecutionPolicy Unrestricted -File "<������ ���� � ����� launcher.ps1>"
    ```
