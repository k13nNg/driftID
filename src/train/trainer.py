import torch
import time

def train_model(classifier,
          loss_func, 
          optimizer,
          features_dl,
          epoch_num = 100):
    '''
    Train the classifier 
    '''
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    classifier.to(device)
    # switch the classifier to train mode
    classifier.train()

    # record start time
    start_time = time.time()

    for epoch in range(epoch_num):
        total_loss = 0
        correct = 0
        total = 0

        for features, labels in features_dl:
            features = features.to(device)
            labels = labels.to(device)

            logits = classifier(features)
            loss = loss_func(logits, labels)

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            total_loss += loss.item()
            
            preds = logits.argmax(dim = 1)
            correct += (preds == labels).sum().item()
            total += labels.size(0)
        
        # calculate average loss
        avg_loss = total_loss / len(features_dl)

        print(
            f"Epoch {epoch+1}/{epoch_num} | "
            f"Loss: {avg_loss:.4f} | "
            f"Acc: {correct/total:.4f}"
        )
    
    # record end time
    end_time = time.time()
    
    # calculate elapsed time and format it into minutes and seconds
    elapsed_time = end_time - start_time
    elapsed_mins = int(elapsed_time // 60)
    elapsed_secs = int(elapsed_time % 60)

    # # save the model params
    # torch.save(classifier.state_dict(), "linear_classifier.pt")

    # torch.save(
    #     {
    #         "model_state_dict": classifier.state_dict(),
    #         "dim": DIM,
    #         "num_classes": NUM_CLASSES,
    #     },
    #     "linear_classifier.pt"
    # )

    print(f"Finished training the model in {elapsed_mins}m {elapsed_secs}s")
    return classifier



