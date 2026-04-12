# 자막 생성 서브에이전트

시나리오 기반으로 자막을 생성하고 영상에 합성하는 서브에이전트입니다.

## 역할

1. 시나리오의 각 단계에서 자막 텍스트 추출
2. 타임스탬프 계산 및 SRT 파일 생성
3. 영상에 자막 합성

## 자막 스타일

### 기본 스타일

```
- 폰트: Apple SD Gothic Neo (macOS) 또는 NanumGothic
- 크기: 48pt (일반), 56pt (강조)
- 색상: 흰색 (#FFFFFF)
- 배경: 반투명 검정 (rgba 0,0,0,0.7)
- 위치: 하단 중앙
```

### 강조 스타일 (중요 단계)

```
- 색상: 노란색 (#FFFF00)
- 테두리: 검정 2px
- 크기: 56pt
```

## SRT 파일 생성

### 입력 (시나리오)

```json
{
  "steps": [
    { "action": "navigate", "caption": "로그인 페이지에 접속합니다", "duration": 2 },
    { "action": "click", "caption": "이메일 입력란을 클릭합니다", "duration": 1.5 },
    { "action": "type", "caption": "이메일 주소를 입력합니다", "duration": 2 },
    { "action": "click", "caption": "로그인 버튼을 클릭합니다", "duration": 1.5, "emphasis": true }
  ]
}
```

### 출력 (SRT)

```srt
1
00:00:00,000 --> 00:00:02,000
로그인 페이지에 접속합니다

2
00:00:02,000 --> 00:00:03,500
이메일 입력란을 클릭합니다

3
00:00:03,500 --> 00:00:05,500
이메일 주소를 입력합니다

4
00:00:05,500 --> 00:00:07,000
<font color="#FFFF00">로그인 버튼을 클릭합니다</font>
```

## SRT 생성 로직

```python
def generate_srt(steps):
    srt_content = ""
    current_time = 0

    for i, step in enumerate(steps, 1):
        start = format_time(current_time)
        duration = step.get('duration', 2)  # 기본 2초
        end = format_time(current_time + duration)

        caption = step.get('caption', '')
        if step.get('emphasis'):
            caption = f'<font color="#FFFF00">{caption}</font>'

        srt_content += f"{i}\n{start} --> {end}\n{caption}\n\n"
        current_time += duration

    return srt_content

def format_time(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds % 1) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"
```

## 자막 합성 (ffmpeg)

### 기본 자막 합성

```bash
ffmpeg -i input.mp4 \
  -vf "subtitles=captions.srt:force_style='FontName=Apple SD Gothic Neo,FontSize=48,PrimaryColour=&HFFFFFF,BackColour=&H80000000,BorderStyle=4,Outline=0,Shadow=0,MarginV=50'" \
  -c:v libx264 -c:a copy \
  output_with_captions.mp4
```

### 스타일 옵션

| 옵션 | 설명 | 예시 |
|------|------|------|
| FontName | 폰트 이름 | Apple SD Gothic Neo |
| FontSize | 폰트 크기 | 48 |
| PrimaryColour | 텍스트 색상 (ABGR) | &HFFFFFF (흰색) |
| BackColour | 배경 색상 | &H80000000 (반투명 검정) |
| BorderStyle | 테두리 스타일 | 1=outline, 3=box, 4=background |
| MarginV | 하단 여백 | 50 |
| Alignment | 정렬 | 2=하단중앙, 8=상단중앙 |

### 한글 폰트 처리

```bash
# macOS에서 사용 가능한 한글 폰트 확인
fc-list :lang=ko | head -10

# 폰트 파일 직접 지정 (더 안정적)
ffmpeg -i input.mp4 \
  -vf "subtitles=captions.srt:fontsdir=/System/Library/Fonts:force_style='FontName=AppleSDGothicNeo-Regular'" \
  output.mp4
```

## 자막 위치 변경

```bash
# 상단 배치 (제목용)
-vf "subtitles=title.srt:force_style='Alignment=8,MarginV=30,FontSize=56,PrimaryColour=&H00FFFF'"

# 하단 배치 (설명용)
-vf "subtitles=desc.srt:force_style='Alignment=2,MarginV=50,FontSize=48'"
```

## 다중 자막 레이어

```bash
# 제목 + 설명 동시 표시
ffmpeg -i input.mp4 \
  -vf "[0:v]subtitles=title.srt:force_style='Alignment=8,MarginV=30,FontSize=56,PrimaryColour=&H00FFFF'[v1];[v1]subtitles=desc.srt:force_style='Alignment=2,MarginV=50,FontSize=48'" \
  -c:v libx264 -c:a copy \
  output.mp4
```

## 자동 자막 생성 규칙

시나리오에 caption이 없는 경우 action 기반으로 자동 생성:

| action | 자동 생성 자막 |
|--------|---------------|
| navigate | "{url} 페이지로 이동합니다" |
| click | "버튼을 클릭합니다" |
| type | "텍스트를 입력합니다" |
| wait | "잠시 기다립니다..." |
| scroll | "스크롤합니다" |

## 출력

- `output/manuals/{title}.srt` - 자막 파일
- `output/manuals/{title}_captioned.mp4` - 자막 합성 영상
