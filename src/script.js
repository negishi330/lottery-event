class LotterySystem {
    constructor() {
        this.isAnimating = false;
        this.history = [];
        
        this.initializeElements();
        this.bindEvents();
        this.loadDefaultCandidates();
    }

    initializeElements() {
        this.startButton = document.getElementById('start-lottery');
        this.resetButton = document.getElementById('reset-lottery');
        this.resultDisplay = document.getElementById('result-display');
        this.animationDurationInput = document.getElementById('animation-duration');
        this.maxNumberInput = document.getElementById('max-number');
        this.historyContainer = document.getElementById('lottery-history');
        
        // モーダル関連の要素
        this.settingsButton = document.getElementById('settings-button');
        this.settingsModal = document.getElementById('settings-modal');
        this.closeSettingsButton = document.getElementById('close-settings');
        this.saveSettingsButton = document.getElementById('save-settings');
        this.cancelSettingsButton = document.getElementById('cancel-settings');
        
        // メモ関連の要素
        this.addMemoButton = document.getElementById('add-memo-button');
    }

    bindEvents() {
        this.startButton.addEventListener('click', () => this.startLottery());
        this.resetButton.addEventListener('click', () => this.resetLottery());
        this.maxNumberInput.addEventListener('input', () => this.updateMaxNumber());
        
        // モーダル関連のイベント
        this.settingsButton.addEventListener('click', () => this.openSettings());
        this.closeSettingsButton.addEventListener('click', () => this.closeSettings());
        this.saveSettingsButton.addEventListener('click', () => this.saveSettings());
        this.cancelSettingsButton.addEventListener('click', () => this.closeSettings());
        
        // モーダル外クリックで閉じる
        this.settingsModal.addEventListener('click', (e) => {
            if (e.target === this.settingsModal) {
                this.closeSettings();
            }
        });
        
        // メモ関連のイベント
        this.addMemoButton.addEventListener('click', () => this.showMemoModal());
    }

    loadDefaultCandidates() {
        this.updateMaxNumber();
    }

    updateMaxNumber() {
        this.maxNumber = parseInt(this.maxNumberInput.value) || 100;
    }
    
    openSettings() {
        this.settingsModal.style.display = 'block';
        document.body.style.overflow = 'hidden'; // スクロール防止
    }
    
    closeSettings() {
        this.settingsModal.style.display = 'none';
        document.body.style.overflow = 'auto'; // スクロール復活
    }
    
    saveSettings() {
        this.updateMaxNumber();
        this.closeSettings();
    }
    
    showMemoModal() {
        // メモ入力モーダルを表示
        const memoModal = document.createElement('div');
        memoModal.className = 'modal';
        memoModal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h2>📝 メモ追加</h2>
                    <button class="close-button">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="setting-item">
                        <label for="memo-text">メモ内容:</label>
                        <textarea id="memo-text" rows="4" placeholder="メモを入力してください..."></textarea>
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="save-button">保存</button>
                    <button class="cancel-button">キャンセル</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(memoModal);
        memoModal.style.display = 'block';
        
        // イベントリスナーを追加
        const closeButton = memoModal.querySelector('.close-button');
        const saveButton = memoModal.querySelector('.save-button');
        const cancelButton = memoModal.querySelector('.cancel-button');
        
        const closeModal = () => {
            document.body.removeChild(memoModal);
        };
        
        closeButton.addEventListener('click', closeModal);
        saveButton.addEventListener('click', () => {
            const memoText = memoModal.querySelector('#memo-text').value.trim();
            if (memoText) {
                this.addMemoToLatest(memoText);
            }
            closeModal();
        });
        cancelButton.addEventListener('click', closeModal);
        
        // モーダル外クリックで閉じる
        memoModal.addEventListener('click', (e) => {
            if (e.target === memoModal) {
                closeModal();
            }
        });
    }
    
    addMemoToLatest(memoText) {
        if (this.history.length > 0) {
            this.history[0].memo = memoText;
            this.updateHistoryDisplay();
            this.saveHistory();
        }
    }
    
    editMemo(index) {
        const item = this.history[index];
        if (!item) return;
        
        // メモ編集モーダルを表示
        const memoModal = document.createElement('div');
        memoModal.className = 'modal';
        memoModal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h2>📝 メモ編集</h2>
                    <button class="close-button">&times;</button>
                </div>
                <div class="modal-body">
                    <div class="setting-item">
                        <label for="memo-text">メモ内容:</label>
                        <textarea id="memo-text" rows="4" placeholder="メモを入力してください...">${item.memo || ''}</textarea>
                    </div>
                </div>
                <div class="modal-footer">
                    <button class="save-button">保存</button>
                    <button class="cancel-button">キャンセル</button>
                </div>
            </div>
        `;
        
        document.body.appendChild(memoModal);
        memoModal.style.display = 'block';
        
        // イベントリスナーを追加
        const closeButton = memoModal.querySelector('.close-button');
        const saveButton = memoModal.querySelector('.save-button');
        const cancelButton = memoModal.querySelector('.cancel-button');
        
        const closeModal = () => {
            document.body.removeChild(memoModal);
        };
        
        closeButton.addEventListener('click', closeModal);
        saveButton.addEventListener('click', () => {
            const memoText = memoModal.querySelector('#memo-text').value.trim();
            item.memo = memoText;
            this.updateHistoryDisplay();
            this.saveHistory();
            closeModal();
        });
        cancelButton.addEventListener('click', closeModal);
        
        // モーダル外クリックで閉じる
        memoModal.addEventListener('click', (e) => {
            if (e.target === memoModal) {
                closeModal();
            }
        });
    }

    startLottery() {
        if (this.isAnimating || this.maxNumber <= 0) {
            return;
        }

        this.isAnimating = true;
        this.startButton.disabled = true;
        this.resetButton.disabled = true;

        // 2進数演出を直接開始
        const finalWinner = this.selectWinner();
        this.startBinaryAnimation(finalWinner);
    }

    startAnimation(duration) {
        // 最終的な当選者を事前に決定
        const finalWinner = this.selectWinner();
        
        // 演出時間を待機してから2進数演出を開始
        setTimeout(() => {
            this.finishAnimation(finalWinner);
        }, duration);
    }

    showCandidate(number) {
        // この関数は使用されなくなったため、削除可能
    }

    finishAnimation(finalWinner) {
        // この関数は使用されなくなったため、削除可能
    }

    selectWinner() {
        // 重み付きランダム選択（履歴に基づいて重複を避ける）
        const recentWinners = this.history.slice(-3).map(item => item.winner);
        const availableNumbers = [];
        
        for (let i = 1; i <= this.maxNumber; i++) {
            if (!recentWinners.includes(i)) {
                availableNumbers.push(i);
            }
        }
        
        // 最近の当選者を避けられない場合は全番号から選択
        const numbersToUse = availableNumbers.length > 0 ? availableNumbers : Array.from({length: this.maxNumber}, (_, i) => i + 1);
        
        const randomIndex = Math.floor(Math.random() * numbersToUse.length);
        return numbersToUse[randomIndex];
    }

    startBinaryAnimation(finalWinner) {
        // 当選番号を2進数に変換（0ベースのインデックスに変換）
        const winnerIndex = finalWinner - 1; // 1ベースから0ベースに変換
        const binaryString = winnerIndex.toString(2);
        const maxDigits = Math.max(7, binaryString.length); // 最低7桁、必要に応じて拡張
        
        // 演出時間を取得（一桁毎の抽選時間）
        const animationDuration = parseFloat(this.animationDurationInput.value) * 1000; // ミリ秒に変換
        
        // 2進数演出の設定
        this.binaryAnimation = {
            finalWinner: finalWinner,
            binaryString: binaryString.padStart(maxDigits, '0'),
            currentDigit: 0,
            maxDigits: maxDigits,
            timePerDigit: animationDuration, // 各桁の演出時間
            interval: null
        };
        
        this.showBinaryAnimation();
    }
    
    showBinaryAnimation() {
        // 2進数の桁数分の枠を表示
        const binaryBoxes = this.createBinaryBoxes();
        
        this.resultDisplay.innerHTML = `
            <div class="binary-animation">
                <div class="binary-display">
                    <div class="binary-boxes">${binaryBoxes}</div>
                    <div class="binary-label">2進数抽選中...</div>
                </div>
                <div class="candidate-display">抽選中...</div>
            </div>
        `;
        
        // 各桁で0と1を高速で切り替える演出を開始
        this.startDigitAnimation(0);
    }
    
    createBinaryBoxes() {
        let boxes = '';
        for (let i = 0; i < this.binaryAnimation.maxDigits; i++) {
            boxes += `<div class="binary-box" data-digit="${i}">?</div>`;
        }
        return boxes;
    }
    
    startDigitAnimation(digitIndex) {
        if (digitIndex >= this.binaryAnimation.maxDigits) {
            // 全桁の演出完了、最終結果表示
            this.showFinalResultInPlace();
            this.addToHistory(this.binaryAnimation.finalWinner);
            this.startButton.disabled = false;
            this.resetButton.disabled = false;
            this.isAnimating = false;
            return;
        }
        
        // 現在の桁で0と1を高速で切り替える
        this.animateDigit(digitIndex, 0);
    }
    
    animateDigit(digitIndex, count) {
        const box = this.resultDisplay.querySelector(`[data-digit="${digitIndex}"]`);
        if (!box) return;
        
        // スロットリール方式で0と1を表示
        const currentValue = count % 2 === 0 ? '0' : '1';
        box.textContent = currentValue;
        box.classList.add('flashing');
        
        // 設定された時間に基づいて演出時間を計算
        const totalAnimationTime = this.binaryAnimation.timePerDigit;
        const maxCount = 20; // 最大20回切り替え（0と1を交互に）
        const progress = count / maxCount;
        const easeOut = 1 - Math.pow(1 - progress, 3); // イージング関数
        
        // 設定時間に基づいて間隔を計算（より正確な計算）
        const baseInterval = totalAnimationTime / (maxCount * 1.5); // イージング効果を考慮した基本間隔
        const interval = baseInterval * (1 + easeOut); // 徐々に遅くなる
        
        // 一定回数切り替えた後、最終値を決定
        if (count < maxCount) {
            setTimeout(() => {
                this.animateDigit(digitIndex, count + 1);
            }, interval);
        } else {
            // 最終値を設定
            const finalValue = this.binaryAnimation.binaryString[digitIndex];
            box.textContent = finalValue;
            box.classList.remove('flashing');
            box.classList.add('final');
            
            // 次の桁の演出を開始（設定された時間に基づく）
            const nextDelay = totalAnimationTime * 0.05; // 各桁の5%の時間
            setTimeout(() => {
                this.startDigitAnimation(digitIndex + 1);
            }, nextDelay);
        }
    }
    
    showFinalResultInPlace() {
        // 既存の表示を活用して最終結果を表示
        const binaryString = this.binaryAnimation.binaryString;
        const finalWinner = this.binaryAnimation.finalWinner;
        
        // 2進数ラベルを結果に変更
        const binaryLabel = this.resultDisplay.querySelector('.binary-label');
        if (binaryLabel) {
            binaryLabel.textContent = `2進数: ${binaryString}`;
        }
        
        // 候補者表示を当選番号に変更
        const candidateDisplay = this.resultDisplay.querySelector('.candidate-display');
        if (candidateDisplay) {
            candidateDisplay.innerHTML = `🎉 ${finalWinner}番 🎉`;
            candidateDisplay.classList.add('winner');
        }
        
        // 勝利エフェクト
        this.resultDisplay.style.animation = 'winner-appear 0.5s ease-out';
        setTimeout(() => {
            this.resultDisplay.style.animation = '';
        }, 500);
    }
    
    showWinner(winner) {
        this.resultDisplay.innerHTML = `
            <div class="winner">
                🎉 ${winner}番 🎉
            </div>
        `;
        
        // 勝利エフェクト
        this.resultDisplay.style.animation = 'winner-appear 0.5s ease-out';
        setTimeout(() => {
            this.resultDisplay.style.animation = '';
        }, 500);
    }

    addToHistory(winner) {
        const timestamp = new Date();
        const historyItem = {
            winner: winner,
            timestamp: timestamp,
            memo: '' // メモフィールドを追加
        };
        
        this.history.unshift(historyItem); // 最新を先頭に追加
        
        // 履歴表示を更新
        this.updateHistoryDisplay();
        
        // ローカルストレージに保存
        this.saveHistory();
    }

    updateHistoryDisplay() {
        this.historyContainer.innerHTML = '';
        
        this.history.forEach((item, index) => {
            const historyElement = document.createElement('div');
            historyElement.className = 'history-item';
            
            const timeString = item.timestamp.toLocaleString('ja-JP', {
                year: 'numeric',
                month: '2-digit',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit'
            });
            
            const memoDisplay = item.memo ? `<div class="memo-text">${item.memo}</div>` : '';
            
            historyElement.innerHTML = `
                <div class="history-content">
                    <span class="winner-name">${item.winner}番</span>
                    <span class="timestamp">${timeString}</span>
                </div>
                ${memoDisplay}
                <button class="edit-memo-button" data-index="${index}">📝</button>
            `;
            
            // メモ編集ボタンのイベントを追加
            const editButton = historyElement.querySelector('.edit-memo-button');
            editButton.addEventListener('click', () => this.editMemo(index));
            
            this.historyContainer.appendChild(historyElement);
        });
    }

    saveHistory() {
        try {
            const historyData = this.history.map(item => ({
                winner: item.winner,
                timestamp: item.timestamp.toISOString(),
                memo: item.memo || ''
            }));
            localStorage.setItem('lotteryHistory', JSON.stringify(historyData));
        } catch (error) {
            console.warn('履歴の保存に失敗しました:', error);
        }
    }

    loadHistory() {
        try {
            const savedHistory = localStorage.getItem('lotteryHistory');
            if (savedHistory) {
                const historyData = JSON.parse(savedHistory);
                this.history = historyData.map(item => ({
                    winner: item.winner,
                    timestamp: new Date(item.timestamp),
                    memo: item.memo || ''
                }));
                this.updateHistoryDisplay();
            }
        } catch (error) {
            console.warn('履歴の読み込みに失敗しました:', error);
        }
    }

    resetLottery() {
        this.resultDisplay.innerHTML = '<div class="placeholder">結果がここに表示されます</div>';
        this.startButton.disabled = false;
        this.resetButton.disabled = true;
        this.isAnimating = false;
    }

    // 初期化時に履歴を読み込み
    init() {
        this.loadHistory();
    }
}

// ページ読み込み完了時に抽選システムを初期化
document.addEventListener('DOMContentLoaded', () => {
    const lotterySystem = new LotterySystem();
    lotterySystem.init();
    
    // グローバルにアクセス可能にする（デバッグ用）
    window.lotterySystem = lotterySystem;
});
