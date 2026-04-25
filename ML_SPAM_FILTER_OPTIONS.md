# Machine Learning — SMS Spam Filtering Options

## Context
The JJ Clover Smart SMS Dispatch System is an offline Android app that processes SMS orders. A spam filter would prevent junk/unwanted SMS from flooding the system and triggering false processing.

---

## Option 1: On-Device ML with TensorFlow Lite (Recommended)

Train a text classification model offline, then run it on-device using TFLite.

### How It Works
1. **Train** a text classification model (Python/TensorFlow) on labeled SMS data (spam vs. legitimate orders)
2. **Convert** the trained model to TFLite format (`.tflite`) — lightweight, typically a few hundred KB
3. **Bundle** the `.tflite` file in the Flutter app's assets
4. **Run inference on-device** using the `tflite_flutter` package

### Integration Flow
```
SMS received → TFLite spam check → if spam, discard/log → else, pass to SmsParser
```

### Pros
- Fully offline — no internet required
- Fast inference (milliseconds per message)
- Small model size fits mobile constraints
- Impressive for thesis/capstone presentation

### Cons
- Needs labeled training data (spam + legitimate SMS samples)
- Model accuracy depends on dataset quality and size
- Requires Python environment for training phase
- Additional native dependency (`tflite_flutter`)

### Dependencies
- `tflite_flutter` (Flutter package)
- TensorFlow / Keras (Python, for training only)

---

## Option 2: Rule-Based Scoring Heuristic (Simplest)

Use a weighted scoring system to flag suspicious messages without a trained model.

### How It Works
Assign points based on message characteristics, flag as spam if score exceeds a threshold.

### Scoring Criteria
| Criteria | Score |
|----------|-------|
| Sender NOT in customer database | +3 |
| Message does NOT match any known command (DELIVER, DROP, YES, STATUS) | +2 |
| Message contains URLs or links | +3 |
| Message contains excessive special characters | +2 |
| Message length > 160 characters | +1 |
| Same sender sent 5+ messages in 1 minute | +3 |
| Message contains common spam keywords (promo, free, win, click) | +2 |

**Threshold:** Score >= 5 → flag as spam

### Integration Flow
```
SMS received → calculate spam score → if score >= threshold, discard/log → else, pass to SmsParser
```

### Pros
- No training data needed
- No external dependencies
- Easy to implement and tune
- Fully offline
- Transparent — easy to explain why a message was flagged

### Cons
- Not technically "machine learning"
- Less adaptive to new spam patterns
- Requires manual threshold tuning
- May produce false positives on unusual legitimate messages

### Dependencies
- None (pure Dart implementation)

---

## Option 3: Naive Bayes Classifier (Pure Dart ML)

Implement a classic machine learning algorithm directly in Dart with no external ML framework.

### How It Works
1. **Tokenize** SMS text into individual words
2. **Train** using labeled data — calculate word probabilities for spam vs. ham (legitimate)
3. **Classify** new messages by multiplying word probabilities and comparing spam vs. ham likelihood
4. **Store** trained weights in SQLite for persistence
5. **Retrain** on-device as new messages arrive (optional)

### Algorithm Summary
```
P(spam | message) = P(word1 | spam) * P(word2 | spam) * ... * P(spam)
P(ham  | message) = P(word1 | ham)  * P(word2 | ham)  * ... * P(ham)

If P(spam) > P(ham) → classify as spam
```

### Integration Flow
```
SMS received → tokenize → Naive Bayes classify → if spam, discard/log → else, pass to SmsParser
```

### Pros
- True machine learning algorithm
- No native dependencies — pure Dart
- Lightweight and fast
- Can improve over time with on-device retraining
- Good balance of simplicity and effectiveness

### Cons
- Less powerful than deep learning models
- Requires manual implementation of the algorithm
- Needs initial training dataset
- Assumes word independence (the "naive" assumption)

### Dependencies
- None (pure Dart implementation, weights stored in SQLite)

---

## Recommendation

| Approach | Complexity | ML Credibility | Effort | Best For |
|----------|-----------|----------------|--------|----------|
| TFLite | High | High | High | Thesis showcase |
| Rule-Based | Low | Low | Low | Quick protection |
| Naive Bayes | Medium | Medium | Medium | Balanced approach |

### Suggested Strategy
1. **Implement Option 2 (Rule-Based) first** — immediate spam protection with minimal effort
2. **Layer Option 1 (TFLite) or Option 3 (Naive Bayes) on top** as a stretch goal for added ML credibility

> **Note:** The current `SmsParser` already rejects messages that don't match known command patterns. A spam filter would add a layer *before* the parser to catch junk from unknown senders and reduce unnecessary processing.
