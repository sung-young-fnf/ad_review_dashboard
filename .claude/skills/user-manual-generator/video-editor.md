# Video Editor Skill

녹화된 영상을 **Claude가 직접 분석**하여 필요한 구간을 자동으로 추출하고, 이어붙이고, 효과를 적용하는 후처리 skill입니다.

## 워크플로우

```
1. 프레임 추출 (1초 간격)
2. Claude가 프레임 이미지 분석 → 화면 변화 감지
3. 필요한 구간 자동 식별 및 추출
4. 잘라서 이어붙이기 (concat)
5. 효과 적용 (자막, zoom, highlight)
6. GIF 변환
```

## Step 1: 프레임 추출 및 분석 (Claude 수행)

### 1.1 영상 정보 및 프레임 추출

```bash
# 영상 길이 확인
ffprobe -v error -show_entries format=duration -of csv=p=0 input.mp4

# 1초 간격으로 프레임 추출
mkdir -p /tmp/frames
ffmpeg -i input.mp4 -vf "fps=1" -q:v 2 /tmp/frames/frame_%03d.jpg 2>/dev/null
ls /tmp/frames/
```

### 1.2 Claude가 프레임 이미지 읽기

```
Read /tmp/frames/frame_001.jpg  # 1초
Read /tmp/frames/frame_005.jpg  # 5초
Read /tmp/frames/frame_010.jpg  # 10초
... (필요한 만큼)
```

### 1.3 화면 변화 감지 기준

Claude는 다음을 기준으로 구간을 식별합니다:
- **URL 변경**: 페이지 이동 감지
- **주요 UI 요소 출현/변경**: 버튼, 모달, 폼 등
- **로딩 완료**: 스켈레톤 → 실제 콘텐츠
- **사용자 액션 결과**: 클릭 후 반응

### 1.4 구간 자동 결정

분석 결과 예시:
```
프레임 분석 결과:
- frame_001 (1초): 로그인 페이지 로딩
- frame_003 (3초): 로그인 페이지 완료 ✓ START
- frame_005 (5초): 로그인 페이지 (동일)
- frame_008 (8초): SSO 버튼 클릭됨 ✓ KEY MOMENT
- frame_012 (12초): 프로젝트 페이지 표시 ✓ END

추천 구간: 3-14초
```

## Step 2: 구간 정의 (자동 생성)

```json
{
  "inputFile": "docs/manuals/output/consumer/01-sso-login.mp4",
  "segments": [
    { "start": "00:00:02", "end": "00:00:08", "label": "로그인 페이지" },
    { "start": "00:00:15", "end": "00:00:25", "label": "SSO 버튼 클릭" },
    { "start": "00:00:40", "end": "00:00:55", "label": "대시보드 표시" }
  ],
  "outputFile": "docs/manuals/output/consumer/01-sso-login-edited.mp4"
}
```

## Step 3: 구간 추출 및 이어붙이기

### 방법 A: 개별 추출 후 concat (안정적)

```bash
# 구간별 추출
ffmpeg -i input.mp4 -ss 00:00:02 -to 00:00:08 -c copy /tmp/part1.mp4
ffmpeg -i input.mp4 -ss 00:00:15 -to 00:00:25 -c copy /tmp/part2.mp4
ffmpeg -i input.mp4 -ss 00:00:40 -to 00:00:55 -c copy /tmp/part3.mp4

# concat 목록 생성
cat > /tmp/concat_list.txt << EOF
file '/tmp/part1.mp4'
file '/tmp/part2.mp4'
file '/tmp/part3.mp4'
EOF

# 이어붙이기
ffmpeg -f concat -safe 0 -i /tmp/concat_list.txt -c copy output_concat.mp4

# 임시 파일 정리
rm /tmp/part*.mp4 /tmp/concat_list.txt
```

### 방법 B: filter_complex로 한번에 (빠름)

```bash
ffmpeg -i input.mp4 -filter_complex \
  "[0:v]trim=start=2:end=8,setpts=PTS-STARTPTS[v1]; \
   [0:v]trim=start=15:end=25,setpts=PTS-STARTPTS[v2]; \
   [0:v]trim=start=40:end=55,setpts=PTS-STARTPTS[v3]; \
   [v1][v2][v3]concat=n=3:v=1:a=0[out]" \
  -map "[out]" -c:v libx264 -preset fast -crf 18 output_edited.mp4
```

## Step 4: 효과 적용

### 4.1 자막 추가 (SRT 파일 사용)

```bash
# SRT 파일 생성
cat > captions.srt << 'EOF'
1
00:00:00,000 --> 00:00:03,000
MCP-Orbit 로그인 페이지에 접속합니다

2
00:00:03,000 --> 00:00:06,000
SSO 로그인 버튼을 클릭합니다

3
00:00:06,000 --> 00:00:10,000
로그인 완료! 대시보드로 이동합니다
EOF

# 자막 번인 (영상에 직접 삽입)
ffmpeg -i input.mp4 -vf "subtitles=captions.srt:force_style='FontSize=24,FontName=Malgun Gothic,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,MarginV=30'" output_subtitled.mp4
```

### 4.2 Zoom 효과 (특정 구간)

```bash
# 1.3배 줌인 효과 (3초~6초 구간)
ffmpeg -i input.mp4 -vf "
  zoompan=z='if(between(t,3,6),1.3,1)':
  x='iw/2-(iw/zoom/2)':
  y='ih/2-(ih/zoom/2)':
  d=1:s=1280x800:fps=30
" output_zoomed.mp4
```

### 4.3 하이라이트 박스

```bash
# 녹색 박스 (3초~5초 구간, 버튼 위치)
ffmpeg -i input.mp4 -vf "
  drawbox=x=500:y=300:w=280:h=50:
  color=green@0.5:t=3:
  enable='between(t,3,5)'
" output_highlight.mp4

# 여러 박스 (시간별)
ffmpeg -i input.mp4 -vf "
  drawbox=x=500:y=300:w=280:h=50:color=green@0.5:t=3:enable='between(t,3,5)',
  drawbox=x=100:y=200:w=200:h=40:color=blue@0.5:t=3:enable='between(t,6,8)'
" output_multi_highlight.mp4
```

### 4.4 통합 효과 적용

```bash
ffmpeg -i input.mp4 -vf "
  subtitles=captions.srt:force_style='FontSize=24,PrimaryColour=&HFFFFFF,Outline=2,MarginV=30',
  drawbox=x=500:y=300:w=280:h=50:color=green@0.5:t=3:enable='between(t,3,5)'
" -c:v libx264 -preset medium -crf 20 output_final.mp4
```

## Step 5: GIF 변환

```bash
# 고품질 GIF (palette 사용)
ffmpeg -i output_final.mp4 \
  -vf "fps=12,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  output_final.gif

# 파일 크기 확인
ls -lh output_final.gif
```

## 자동화 스크립트

### edit-video.sh

```bash
#!/bin/bash
# 사용법: ./edit-video.sh input.mp4 "2-8,15-25,40-55" output.mp4

INPUT=$1
SEGMENTS=$2
OUTPUT=$3

# 구간 파싱 및 추출
IFS=',' read -ra PARTS <<< "$SEGMENTS"
FILTER=""
CONCAT=""
i=0

for PART in "${PARTS[@]}"; do
  START=$(echo $PART | cut -d'-' -f1)
  END=$(echo $PART | cut -d'-' -f2)
  FILTER+="[0:v]trim=start=$START:end=$END,setpts=PTS-STARTPTS[v$i];"
  CONCAT+="[v$i]"
  ((i++))
done

CONCAT+="concat=n=$i:v=1:a=0[out]"

ffmpeg -i "$INPUT" -filter_complex "${FILTER}${CONCAT}" -map "[out]" -c:v libx264 -preset fast -crf 18 "$OUTPUT"

echo "✅ 완료: $OUTPUT"
```

## 대화형 워크플로우

1. **미리보기 시작**
   ```
   사용자: 01-sso-login.mp4 편집할게
   Claude: 4배속 미리보기를 시작합니다. 필요한 구간의 시작/끝 시간을 메모해주세요.
   [ffplay 실행]
   ```

2. **구간 수집**
   ```
   Claude: 어떤 구간들이 필요한가요? (예: 2-8, 15-25)
   사용자: 5-12초, 20-35초, 50-65초
   ```

3. **편집 및 효과**
   ```
   Claude: 구간을 이어붙이고 있습니다...
   Claude: 자막을 추가할까요? (Y/N)
   Claude: 하이라이트 박스가 필요한 위치가 있나요?
   ```

4. **최종 출력**
   ```
   Claude: 편집 완료!
   - MP4: output/01-sso-login-edited.mp4 (1.2MB)
   - GIF: output/01-sso-login-edited.gif (450KB)
   ```

## Exit Criteria

- [ ] 배속 미리보기로 구간 확인 완료
- [ ] 필요한 구간들 추출 및 이어붙이기 완료
- [ ] 자막/효과 적용 완료
- [ ] GIF 변환 완료
- [ ] 최종 파일 크기 확인
