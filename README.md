# 🚀 저장소 가이드

GitHub 저장소를 처음 생성하거나 기존 프로젝트를 연동할 때 사용하는 Git 명령어 안내입니다.

## 1. 터미널에서 새로운 저장소 생성하기 (Create a new repository)

현재 로컬 폴더를 새로운 Git 저장소로 초기화하고 원격 저장소에 첫 커밋을 푸시합니다.

```bash
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/smilewonjin/deploy-vuln-check.git
git push -u origin main
```

## 2. 기존 로컬 저장소 연결하기 (Push an existing repository)

이미 작업 중이던 로컬 Git 프로젝트가 있다면 원격 저장소 주소만 연결하여 푸시합니다.

```bash
git remote add origin https://github.com/smilewonjin/azure.git
git branch -M main
git push -u origin main
```