# 영상 주석 효과 서브에이전트

영상에 Zoom 효과, 하이라이트 박스, 화살표 등 주석 효과를 추가하는 서브에이전트입니다.

## 역할

1. 특정 시점에 Zoom In/Out 효과 적용
2. 클릭 영역에 하이라이트 박스 표시
3. 화살표 및 마커 추가

## Zoom 효과

### Zoom In (확대)

```bash
# 중앙 기준 1.5배 확대 (2초 동안)
ffmpeg -i input.mp4 -vf "
  zoompan=z='if(between(t,3,5),min(zoom+0.01,1.5),zoom)':
  x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':
  d=1:s=1280x720:fps=30
" -c:v libx264 output.mp4
```

### 특정 좌표로 Zoom

```bash
# (X, Y) 좌표 중심으로 확대
# 예: 버튼 위치 (640, 400)으로 줌
ffmpeg -i input.mp4 -vf "
  zoompan=z='if(between(t,2,4),1.5,1)':
  x='if(between(t,2,4),640-iw/zoom/2,iw/2-iw/zoom/2)':
  y='if(between(t,2,4),400-ih/zoom/2,ih/2-ih/zoom/2)':
  d=1:s=1280x720:fps=30
" output.mp4
```

### Zoom Out (축소 → 원본)

```bash
ffmpeg -i input.mp4 -vf "
  zoompan=z='if(lte(t,0),1.5,max(zoom-0.008,1))':
  x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':
  d=1:s=1280x720:fps=30
" output.mp4
```

## 하이라이트 박스

### 정적 박스 (drawbox)

```bash
# 빨간색 박스 (3초~5초)
ffmpeg -i input.mp4 -vf "
  drawbox=x=100:y=200:w=300:h=50:
  color=red@0.8:t=3:
  enable='between(t,3,5)'
" -c:v libx264 output.mp4
```

### 색상 옵션

| 색상 | 값 | 용도 |
|------|-----|------|
| 빨강 | `red@0.8` | 경고, 중요 |
| 초록 | `green@0.8` | 성공, 완료 |
| 파랑 | `blue@0.8` | 정보 |
| 노랑 | `yellow@0.8` | 주의 |

### 깜빡이는 박스 (pulse 효과)

```bash
# 0.5초 간격으로 깜빡임
ffmpeg -i input.mp4 -vf "
  drawbox=x=100:y=200:w=300:h=50:
  color=red@0.8:t=3:
  enable='between(t,3,5)*lt(mod(t,1),0.5)'
" output.mp4
```

### 둥근 모서리 박스 (overlay 방식)

```bash
# 1. 박스 이미지 생성 (ImageMagick)
convert -size 300x50 xc:none -fill none -stroke red -strokewidth 3 \
  -draw "roundrectangle 0,0,299,49,10,10" highlight_box.png

# 2. 영상에 오버레이
ffmpeg -i input.mp4 -i highlight_box.png -filter_complex "
  [1:v]format=rgba[box];
  [0:v][box]overlay=x=100:y=200:enable='between(t,3,5)'
" output.mp4
```

## 화살표 효과

```bash
# 1. 화살표 이미지 생성
convert -size 100x50 xc:none -fill red -draw "polygon 50,0 100,25 50,50 50,35 0,35 0,15 50,15" arrow.png

# 2. 영상에 오버레이
ffmpeg -i input.mp4 -i arrow.png -filter_complex "
  [0:v][1:v]overlay=x=200:y=150:enable='between(t,2,4)'
" output.mp4
```

## 클릭 효과 (원형 ripple)

```bash
# 클릭 위치에 확장되는 원
ffmpeg -i input.mp4 -vf "
  drawbox=x='640-50*min((t-3)*5,1)':
  y='400-50*min((t-3)*5,1)':
  w='100*min((t-3)*5,1)':
  h='100*min((t-3)*5,1)':
  color=yellow@0.5:t=2:
  enable='between(t,3,3.5)'
" output.mp4
```

## 텍스트 레이블 (drawtext)

```bash
# 버튼 옆에 설명 텍스트
ffmpeg -i input.mp4 -vf "
  drawtext=text='여기를 클릭!':
  fontfile=/System/Library/Fonts/AppleSDGothicNeo.ttc:
  fontsize=32:fontcolor=white:
  box=1:boxcolor=red@0.8:boxborderw=10:
  x=450:y=180:
  enable='between(t,3,5)'
" output.mp4
```

## 복합 효과 (filter_complex)

```bash
# Zoom + Box + Text 동시 적용
ffmpeg -i input.mp4 -filter_complex "
  [0:v]
  zoompan=z='if(between(t,3,5),1.3,1)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=30,
  drawbox=x=100:y=200:w=300:h=50:color=red@0.8:t=3:enable='between(t,3,5)',
  drawtext=text='로그인 버튼':fontfile=/System/Library/Fonts/AppleSDGothicNeo.ttc:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.7:x=150:y=260:enable='between(t,3,5)'
  [v]
" -map "[v]" -c:v libx264 output.mp4
```

## 효과 타이밍 계산

시나리오에서 효과 시작/종료 시간 계산:

```python
def calculate_effect_timing(steps):
    effects = []
    current_time = 0

    for step in steps:
        duration = step.get('duration', 2)

        if 'zoom' in step:
            effects.append({
                'type': 'zoom',
                'start': current_time,
                'end': current_time + step['zoom'].get('duration', duration),
                'scale': step['zoom'].get('scale', 1.5)
            })

        if 'highlight' in step:
            effects.append({
                'type': 'highlight',
                'start': current_time,
                'end': current_time + step['highlight'].get('duration', 1.5),
                'color': step['highlight'].get('color', 'red'),
                'coords': step.get('element_coords', {'x': 0, 'y': 0, 'w': 100, 'h': 50})
            })

        current_time += duration

    return effects
```

## ffmpeg 필터 생성

```python
def generate_filter_string(effects):
    filters = []

    for effect in effects:
        if effect['type'] == 'zoom':
            filters.append(f"zoompan=z='if(between(t,{effect['start']},{effect['end']}),{effect['scale']},1)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=30")

        elif effect['type'] == 'highlight':
            c = effect['coords']
            filters.append(f"drawbox=x={c['x']}:y={c['y']}:w={c['w']}:h={c['h']}:color={effect['color']}@0.8:t=3:enable='between(t,{effect['start']},{effect['end']})'")

    return ','.join(filters)
```

## 출력

- 효과가 적용된 영상 파일
- 효과 메타데이터 JSON (타이밍, 좌표 정보)
