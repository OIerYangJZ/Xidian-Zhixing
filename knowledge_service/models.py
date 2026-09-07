"""Local BGE inference; model paths/revisions are deployment-owned."""
import os
import threading
import torch
from sentence_transformers import SentenceTransformer, CrossEncoder


class Models:
    def __init__(self):
        self.device=os.environ["KNOWLEDGE_MODEL_DEVICE"]
        self.embedding_name=os.environ["KNOWLEDGE_EMBEDDING_REVISION"]
        self.reranker_name=os.environ["KNOWLEDGE_RERANK_REVISION"]
        self.lock=threading.Lock()
        dtype=torch.float16 if self.device.startswith("cuda") else torch.float32
        self.embedding=SentenceTransformer(os.environ["KNOWLEDGE_EMBEDDING_MODEL"],device=self.device,
            local_files_only=True,model_kwargs={"torch_dtype":dtype})
        self.embedding.max_seq_length=1024
        self.reranker=CrossEncoder(os.environ["KNOWLEDGE_RERANK_MODEL"],device=self.device,max_length=1024,
            local_files_only=True,model_kwargs={"torch_dtype":dtype})
        if self.device.startswith("cuda"):
            self.embedding.half()
            self.reranker.model.half()
            torch.cuda.empty_cache()
        self.dimension=self.embedding.get_sentence_embedding_dimension()

    def encode(self,texts:list[str]):
        with self.lock,torch.inference_mode():
            return self.embedding.encode(texts,batch_size=8,normalize_embeddings=True,show_progress_bar=False).tolist()

    def rerank(self,query:str,rows:list[dict]):
        if not rows:
            return []
        pairs=[(query,row["title"]+"\n"+row["content"]) for row in rows]
        with self.lock,torch.inference_mode():
            scores=self.reranker.predict(pairs,batch_size=8,show_progress_bar=False,activation_fn=torch.nn.Sigmoid())
        return sorted([{**row,"rerankScore":float(score)} for row,score in zip(rows,scores)],key=lambda row:row["rerankScore"],reverse=True)
