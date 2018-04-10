# db2git
### Описание
Скрипт PowerShell для автоматического версионирования объектов базы данных SQL Server
### Установка и настройка
1. Клонируйте этот репозиторий (Репозиторий скрипта)
1. Создайте GIT-репозиторий для хранения истории объектов SQL-сервера (Репозиторий базы).
1. Клонируйте Репозиторий базы.
1. Создайте и заполните в каталоге с репозиторием файл settings.ini следующего вида:
    ```ini
    [General]
    ScriptRepository=git@v-deploy.transasia.ru:soloviov.ae/db2git.git
    DirectoryToSaveTo=<Каталог с репозиторием базы>
    [DB]
    ServerName=Имя SQL-сервера
    Database=Имя базы данных
    Login=Логин пользователя SQL-сервера (аутентификация SQL Server)
    Password=Пароль пользователя SQL-сервера (аутентификация SQL Server)
    ExcludeSchemas=sys,Information_Schema 
    ```
1.  Запустите файл launcher.ps1 в PowerShell или создайте назначенное задание со следующей командой: 
    ```ps
    powershell -ExecutionPolicy Unrestricted -File "<Полный путь к файлу launcher.ps1>"
    ```

